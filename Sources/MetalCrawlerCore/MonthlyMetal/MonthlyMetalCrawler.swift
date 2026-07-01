import Foundation
import JSONArtifactKit

public struct MonthlyMetalCrawler: Sendable {
    private let runsDirectory: URL
    private let knowledgeDirectory: URL
    private let runIDProvider: @Sendable () -> RunID
    private let crawlClientFactory: @Sendable (URL) -> any CrawlClient
    private let llmProviderFactory: @Sendable (MonthlyMetalSourceExtractionConfiguration) -> any LLMProvider

    public init(
        runsDirectory: URL = URL(fileURLWithPath: "runs", isDirectory: true),
        knowledgeDirectory: URL = URL(fileURLWithPath: "knowledge", isDirectory: true)
    ) {
        self.runsDirectory = runsDirectory
        self.knowledgeDirectory = knowledgeDirectory
        self.runIDProvider = { RunID() }
        self.crawlClientFactory = { runDirectory in
            CachedCrawlClient(
                wrapped: URLSessionCrawlClient(),
                cacheDirectory: runDirectory.appendingPathComponent("crawl-cache", isDirectory: true)
            )
        }
        self.llmProviderFactory = { configuration in
            let sessionConfiguration = URLSessionConfiguration.default
            sessionConfiguration.timeoutIntervalForRequest = configuration.requestTimeout
            sessionConfiguration.timeoutIntervalForResource = configuration.requestTimeout

            return OpenAICompatibleLLMProvider(
                baseURL: configuration.baseURL,
                session: URLSession(configuration: sessionConfiguration)
            )
        }
    }

    init(
        runsDirectory: URL,
        knowledgeDirectory: URL,
        runIDProvider: @escaping @Sendable () -> RunID,
        crawlClientFactory: @escaping @Sendable (URL) -> any CrawlClient,
        llmProviderFactory: @escaping @Sendable (MonthlyMetalSourceExtractionConfiguration) -> any LLMProvider = { configuration in
            OpenAICompatibleLLMProvider(baseURL: configuration.baseURL)
        }
    ) {
        self.runsDirectory = runsDirectory
        self.knowledgeDirectory = knowledgeDirectory
        self.runIDProvider = runIDProvider
        self.crawlClientFactory = crawlClientFactory
        self.llmProviderFactory = llmProviderFactory
    }

    public func listCandidates(
        month rawMonth: String,
        sourceExtraction: MonthlyMetalSourceExtractionConfiguration? = nil
    ) async throws -> MonthlyMetalCandidateListResult {
        let month = try parseMonth(rawMonth)
        let runID = runIDProvider()
        let runDirectory = runsDirectory.appendingPathComponent(runID.rawValue, isDirectory: true)

        try FileManager.default.createDirectory(
            at: runDirectory,
            withIntermediateDirectories: true
        )

        let context = ResearchContext(
            month: month,
            runID: runID,
            crawlClient: crawlClientFactory(runDirectory),
            llmFallback: UnavailableLLMExtractionFallback(),
            runsDirectory: runsDirectory,
            knowledgeDirectory: knowledgeDirectory
        )

        let sourceItems = try await MonthlyMetalSourceItemProvider(
            knowledgeDirectory: knowledgeDirectory
        ).sourceItems(for: month, context: context)
        let extractionResults = await extractSourceCandidatesIfNeeded(
            sourceItems: sourceItems,
            configuration: sourceExtraction
        )
        let extractedCandidateMentionCount = extractionResults.reduce(0) { partialResult, result in
            partialResult + result.candidates.count
        }
        let potentialCandidates = potentialCandidates(from: extractionResults)
        let artifacts = try writeArtifacts(
            month: rawMonth,
            sourceItems: sourceItems,
            extractionResults: extractionResults,
            potentialCandidates: potentialCandidates,
            runDirectory: runDirectory
        )

        return MonthlyMetalCandidateListResult(
            runID: runID,
            runDirectory: runDirectory,
            potentialCandidatesArtifactURL: artifacts.potentialCandidates,
            sourceItemsArtifactURL: artifacts.sourceItems,
            sourceExtractionArtifactURL: artifacts.sourceExtraction,
            sourceItems: sourceItems,
            extractedSourceItemCount: extractionResults.count,
            extractedCandidateMentionCount: extractedCandidateMentionCount,
            potentialCandidates: potentialCandidates
        )
    }

    private func parseMonth(_ rawMonth: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        formatter.isLenient = false

        guard let month = formatter.date(from: rawMonth),
              formatter.string(from: month) == rawMonth
        else {
            throw MonthlyMetalError.invalidMonth(rawMonth)
        }

        return month
    }

    private func writeArtifacts(
        month: String,
        sourceItems: [MonthlyMetalSourceItem],
        extractionResults: [MonthlyMetalSourceExtractionResult],
        potentialCandidates: [MonthlyMetalCandidate],
        runDirectory: URL
    ) throws -> MonthlyMetalRunArtifacts {
        let potentialCandidatesURL = try writeArtifact(
            fileName: "monthly-metal-potential-candidates.json",
            data: MonthlyMetalPotentialCandidateArtifact(
                month: month,
                candidates: potentialCandidates
            ),
            runDirectory: runDirectory
        )
        let sourceItemsURL = try writeArtifact(
            fileName: "source-items.json",
            data: MonthlyMetalSourceItemsArtifact(
                month: month,
                sourceItems: sourceItems
            ),
            runDirectory: runDirectory
        )
        let sourceExtractionURL: URL? = if extractionResults.isEmpty {
            nil
        } else {
            try writeArtifact(
                fileName: "source-extracted-candidates.json",
                data: MonthlyMetalSourceExtractionArtifact(
                    month: month,
                    results: extractionResults
                ),
                runDirectory: runDirectory
            )
        }

        return MonthlyMetalRunArtifacts(
            potentialCandidates: potentialCandidatesURL,
            sourceItems: sourceItemsURL,
            sourceExtraction: sourceExtractionURL
        )
    }

    private func writeArtifact<T: Encodable>(
        fileName: String,
        data: T,
        runDirectory: URL
    ) throws -> URL {
        let jsonArtifactGenerator = JSONArtifactGenerator()
        let json = try jsonArtifactGenerator.generateJSON(with: fileName, data: data)

        guard jsonArtifactGenerator.write(to: runDirectory, fileName: fileName, data: json) else {
            throw MonthlyMetalError.invalidOperation("Could not write JSON artifact \(fileName).")
        }

        return runDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    private func extractSourceCandidatesIfNeeded(
        sourceItems: [MonthlyMetalSourceItem],
        configuration: MonthlyMetalSourceExtractionConfiguration?
    ) async -> [MonthlyMetalSourceExtractionResult] {
        guard let configuration else {
            return []
        }

        let extractor = LocalLLMSourceCandidateExtractor(
            provider: llmProviderFactory(configuration),
            model: configuration.model,
            temperature: configuration.temperature,
            maxTokens: configuration.maxTokens
        )
        var results: [MonthlyMetalSourceExtractionResult] = []

        for sourceItem in sourceItems where shouldExtractSourceCandidates(from: sourceItem) {
            results.append(await extractor.extract(from: sourceItem))
        }

        return results
    }

    private func shouldExtractSourceCandidates(
        from sourceItem: MonthlyMetalSourceItem
    ) -> Bool {
        guard sourceItem.sourceKind == "instagram_post" else {
            return true
        }

        let text = sourceItem.text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let albumSignals = [
            "new arrival",
            "new arrivals",
            "vinyl",
            " lp",
            " cd",
            "cassette",
            "tape",
            "full length",
            "full-length",
            "album",
            "demo",
            "ep",
            "black metal",
            "death metal",
            "doom metal",
            "heavy metal",
            "thrash metal"
        ]

        return albumSignals.contains { text.contains($0) }
    }

    private func potentialCandidates(
        from extractionResults: [MonthlyMetalSourceExtractionResult]
    ) -> [MonthlyMetalCandidate] {
        var candidatesByIdentity: [MonthlyMetalReleaseIdentity: MonthlyMetalCandidate] = [:]

        for result in extractionResults {
            for extractedCandidate in result.candidates {
                let candidate = potentialCandidate(
                    from: extractedCandidate,
                    extractionResult: result
                )
                let identity = identity(for: candidate)

                if let existing = candidatesByIdentity[identity] {
                    candidatesByIdentity[identity] = merge(existing, with: candidate)
                } else {
                    candidatesByIdentity[identity] = candidate
                }
            }
        }

        return candidatesByIdentity.values.sorted(by: shouldSortBefore)
    }

    private func potentialCandidate(
        from extractedCandidate: MonthlyMetalExtractedSourceCandidate,
        extractionResult: MonthlyMetalSourceExtractionResult
    ) -> MonthlyMetalCandidate {
        MonthlyMetalCandidate(
            bandName: extractedCandidate.bandName,
            albumTitle: extractedCandidate.albumTitle,
            releaseType: nil,
            labelName: extractedCandidate.labelName,
            releaseDate: nil,
            releaseDateText: extractedCandidate.releaseDateText,
            metalArchivesURL: nil,
            sources: [
                MonthlyMetalCandidateSource(
                    name: extractionResult.sourceName,
                    kind: extractionResult.sourceKind,
                    sourceURL: extractionResult.sourceURL,
                    itemURL: extractionResult.itemURL,
                    signal: extractedCandidate.sourceSignal,
                    evidence: extractedCandidate.evidence,
                    confidence: extractedCandidate.confidence
                )
            ]
        )
    }

    private func merge(
        _ existing: MonthlyMetalCandidate,
        with candidate: MonthlyMetalCandidate
    ) -> MonthlyMetalCandidate {
        MonthlyMetalCandidate(
            bandName: existing.bandName,
            albumTitle: existing.albumTitle,
            releaseType: existing.releaseType ?? candidate.releaseType,
            labelName: existing.labelName ?? candidate.labelName,
            releaseDate: existing.releaseDate ?? candidate.releaseDate,
            releaseDateText: existing.releaseDateText ?? candidate.releaseDateText,
            metalArchivesURL: existing.metalArchivesURL ?? candidate.metalArchivesURL,
            sources: deduplicatedSources(existing.sources + candidate.sources)
        )
    }

    private func deduplicatedSources(
        _ sources: [MonthlyMetalCandidateSource]
    ) -> [MonthlyMetalCandidateSource] {
        var seen = Set<MonthlyMetalCandidateSource>()
        var result: [MonthlyMetalCandidateSource] = []

        for source in sources where seen.insert(source).inserted {
            result.append(source)
        }

        return result
    }

    private func identity(for candidate: MonthlyMetalCandidate) -> MonthlyMetalReleaseIdentity {
        MonthlyMetalReleaseIdentity(
            bandName: candidate.bandName,
            albumTitle: candidate.albumTitle
        )
    }

    private func shouldSortBefore(
        _ lhs: MonthlyMetalCandidate,
        _ rhs: MonthlyMetalCandidate
    ) -> Bool {
        if let lhsDate = lhs.releaseDate,
           let rhsDate = rhs.releaseDate,
           lhsDate != rhsDate
        {
            return lhsDate < rhsDate
        }

        if lhs.releaseDate != nil,
           rhs.releaseDate == nil
        {
            return true
        }

        if lhs.releaseDate == nil,
           rhs.releaseDate != nil
        {
            return false
        }

        if lhs.bandName.localizedCaseInsensitiveCompare(rhs.bandName) != .orderedSame {
            return lhs.bandName.localizedCaseInsensitiveCompare(rhs.bandName) == .orderedAscending
        }

        return lhs.albumTitle.localizedCaseInsensitiveCompare(rhs.albumTitle) == .orderedAscending
    }
}

private struct MonthlyMetalPotentialCandidateArtifact: Encodable {
    let month: String
    let candidates: [MonthlyMetalCandidate]
}

private struct MonthlyMetalSourceItemsArtifact: Encodable {
    let month: String
    let sourceItems: [MonthlyMetalSourceItem]
}

private struct MonthlyMetalRunArtifacts {
    let potentialCandidates: URL
    let sourceItems: URL
    let sourceExtraction: URL?
}

private struct UnavailableLLMExtractionFallback: LLMExtractionFallback {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate {
        throw MonthlyMetalError.invalidOperation("LLM extraction is not used during monthly candidate discovery.")
    }

    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft {
        throw MonthlyMetalError.invalidOperation("Bandcamp extraction is not used during monthly candidate discovery.")
    }
}
