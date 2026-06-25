import Foundation

public struct MonthlyMetalCrawler: Sendable {
    private let runsDirectory: URL
    private let knowledgeDirectory: URL
    private let runIDProvider: @Sendable () -> RunID
    private let crawlClientFactory: @Sendable (URL) -> any CrawlClient
    private let llmProviderFactory: @Sendable (MonthlyMetalLLMExtractionConfiguration) -> any LLMProvider

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
        llmProviderFactory: @escaping @Sendable (MonthlyMetalLLMExtractionConfiguration) -> any LLMProvider = { configuration in
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
        editorialExtraction: MonthlyMetalLLMExtractionConfiguration? = nil
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

        let candidatePoolBuilder = MonthlyMetalCandidatePoolBuilder()
        let candidates = try await candidatePoolBuilder.candidates(for: month, context: context)
        let editorialDocuments = try await EditorialSourceDocumentSource(
            knowledgeDirectory: knowledgeDirectory
        ).documents(for: month, context: context)
        let extractionResults = await extractEditorialCandidatesIfNeeded(
            documents: editorialDocuments,
            configuration: editorialExtraction
        )
        let potentialCandidates = mergedPotentialCandidates(
            catalogCandidates: candidates,
            extractionResults: extractionResults
        )
        let candidateArtifactURL = try writeCandidateArtifact(
            month: rawMonth,
            candidates: candidates,
            fileName: "monthly-metal-candidates.json",
            runDirectory: runDirectory
        )
        let potentialCandidatesArtifactURL = try writeCandidateArtifact(
            month: rawMonth,
            candidates: potentialCandidates,
            fileName: "monthly-metal-potential-candidates.json",
            runDirectory: runDirectory
        )
        let editorialDocumentsArtifactURL = try writeEditorialDocumentsArtifact(
            month: rawMonth,
            documents: editorialDocuments,
            runDirectory: runDirectory
        )
        let editorialExtractionArtifactURL = try writeEditorialExtractionArtifactIfNeeded(
            month: rawMonth,
            extractionResults: extractionResults,
            runDirectory: runDirectory
        )

        return MonthlyMetalCandidateListResult(
            runID: runID,
            runDirectory: runDirectory,
            candidateArtifactURL: candidateArtifactURL,
            potentialCandidatesArtifactURL: potentialCandidatesArtifactURL,
            editorialDocumentsArtifactURL: editorialDocumentsArtifactURL,
            editorialExtractionArtifactURL: editorialExtractionArtifactURL,
            candidates: candidates,
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

    private func writeCandidateArtifact(
        month: String,
        candidates: [MonthlyMetalCandidate],
        fileName: String,
        runDirectory: URL
    ) throws -> URL {
        let artifactURL = runDirectory.appendingPathComponent(
            fileName,
            isDirectory: false
        )
        let artifact = MonthlyMetalCandidateArtifact(
            month: month,
            candidates: candidates
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        try encoder.encode(artifact).write(to: artifactURL)
        return artifactURL
    }

    private func writeEditorialDocumentsArtifact(
        month: String,
        documents: [MonthlyMetalEditorialSourceDocument],
        runDirectory: URL
    ) throws -> URL {
        let artifactURL = runDirectory.appendingPathComponent(
            "editorial-source-documents.json",
            isDirectory: false
        )
        let artifact = MonthlyMetalEditorialDocumentsArtifact(
            month: month,
            documents: documents
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        try encoder.encode(artifact).write(to: artifactURL)
        return artifactURL
    }

    private func writeEditorialExtractionArtifactIfNeeded(
        month: String,
        extractionResults: [MonthlyMetalEditorialExtractionResult],
        runDirectory: URL
    ) throws -> URL? {
        guard !extractionResults.isEmpty else {
            return nil
        }

        let artifactURL = runDirectory.appendingPathComponent(
            "editorial-extracted-candidates.json",
            isDirectory: false
        )
        let artifact = MonthlyMetalEditorialExtractionArtifact(
            month: month,
            results: extractionResults
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        try encoder.encode(artifact).write(to: artifactURL)
        return artifactURL
    }

    private func extractEditorialCandidatesIfNeeded(
        documents: [MonthlyMetalEditorialSourceDocument],
        configuration: MonthlyMetalLLMExtractionConfiguration?
    ) async -> [MonthlyMetalEditorialExtractionResult] {
        guard let configuration else {
            return []
        }

        let extractor = LocalLLMEditorialCandidateExtractor(
            provider: llmProviderFactory(configuration),
            model: configuration.model,
            temperature: configuration.temperature,
            maxTokens: configuration.maxTokens
        )
        var results: [MonthlyMetalEditorialExtractionResult] = []

        for document in documents where shouldExtractEditorialCandidates(from: document) {
            results.append(await extractor.extract(from: document))
        }

        return results
    }

    private func shouldExtractEditorialCandidates(
        from document: MonthlyMetalEditorialSourceDocument
    ) -> Bool {
        guard document.sourceKind == "instagram_post" else {
            return true
        }

        let text = document.text
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

    private func mergedPotentialCandidates(
        catalogCandidates: [MonthlyMetalCandidate],
        extractionResults: [MonthlyMetalEditorialExtractionResult]
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

        for catalogCandidate in catalogCandidates {
            let identity = identity(for: catalogCandidate)

            guard let existing = candidatesByIdentity[identity] else {
                continue
            }

            candidatesByIdentity[identity] = merge(existing, with: catalogCandidate)
        }

        return candidatesByIdentity.values.sorted(by: shouldSortBefore)
    }

    private func potentialCandidate(
        from extractedCandidate: MonthlyMetalExtractedEditorialCandidate,
        extractionResult: MonthlyMetalEditorialExtractionResult
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

private struct MonthlyMetalCandidateArtifact: Encodable {
    let month: String
    let candidates: [MonthlyMetalCandidate]
}

private struct MonthlyMetalEditorialDocumentsArtifact: Encodable {
    let month: String
    let documents: [MonthlyMetalEditorialSourceDocument]
}

private struct UnavailableLLMExtractionFallback: LLMExtractionFallback {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate {
        throw MonthlyMetalError.invalidOperation("LLM extraction is not used during monthly candidate discovery.")
    }

    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft {
        throw MonthlyMetalError.invalidOperation("Bandcamp extraction is not used during monthly candidate discovery.")
    }
}
