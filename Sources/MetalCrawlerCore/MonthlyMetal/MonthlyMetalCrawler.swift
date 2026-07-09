import Foundation
import FileSystemKit
import LocalLLMKit
import SocialSourceKit

public struct MonthlyMetalCrawler: Sendable {
    private let runsDirectory: URL
    private let knowledgeDirectory: URL
    private let runIDProvider: @Sendable () -> RunID
    private let crawlClientFactory: @Sendable (URL) -> any CrawlClient
    private let llmProviderFactory: @Sendable (MonthlyMetalSourceExtractionConfiguration) -> any LLMProvider
    private let fileSystem: any FileSystemManaging

    public init(
        runsDirectory: URL = URL(fileURLWithPath: "runs", isDirectory: true),
        knowledgeDirectory: URL = URL(fileURLWithPath: "knowledge", isDirectory: true)
    ) {
        self.runsDirectory = runsDirectory
        self.knowledgeDirectory = knowledgeDirectory
        self.runIDProvider = { RunID() }
        self.crawlClientFactory = { runDirectory in
            CachedCrawlClient(
                wrapped: MetalArchivesPoliteCrawlClient(
                    wrapped: URLSessionCrawlClient()
                ),
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
        self.fileSystem = FileSystem.shared
    }

    init(
        runsDirectory: URL,
        knowledgeDirectory: URL,
        runIDProvider: @escaping @Sendable () -> RunID,
        crawlClientFactory: @escaping @Sendable (URL) -> any CrawlClient,
        llmProviderFactory: @escaping @Sendable (MonthlyMetalSourceExtractionConfiguration) -> any LLMProvider = { configuration in
            OpenAICompatibleLLMProvider(baseURL: configuration.baseURL)
        },
        fileSystem: any FileSystemManaging = FileSystem.shared
    ) {
        self.runsDirectory = runsDirectory
        self.knowledgeDirectory = knowledgeDirectory
        self.runIDProvider = runIDProvider
        self.crawlClientFactory = crawlClientFactory
        self.llmProviderFactory = llmProviderFactory
        self.fileSystem = fileSystem
    }

    public func listCandidates(
        month rawMonth: String,
        sourceExtraction: MonthlyMetalSourceExtractionConfiguration? = nil,
        recommendations: MonthlyMetalRecommendationConfiguration? = nil
    ) async throws -> MonthlyMetalCandidateListResult {
        
        let month = try parseMonth(rawMonth)
        let runID = runIDProvider()
        let runDirectory = runsDirectory.appendingPathComponent(runID.rawValue, isDirectory: true)
        let factory = crawlClientFactory(runDirectory)

        try fileSystem.ensureDirectory(runDirectory)

        let context = ResearchContext(
            month: month,
            runID: runID,
            crawlClient: factory,
            llmFallback: UnavailableLLMExtractionFallback(),
            runsDirectory: runsDirectory,
            knowledgeDirectory: knowledgeDirectory
        )

        let sourceItems = try await MonthlyMetalSourceItemProvider(knowledgeDirectory: knowledgeDirectory)
            .sourceItems(for: month, context: context)
        
        let extractionResults = await extractSourceCandidatesIfNeeded(sourceItems: sourceItems, configuration: sourceExtraction)
        let extractedCandidateMentionCount = extractionResults.reduce(0) { partialResult, result in
            partialResult + result.candidates.count
        }
        
        let potentialCandidates = potentialCandidates(from: extractionResults)
        let enrichedCandidates = await enrichPotentialCandidates(
            potentialCandidates,
            sourceItems: sourceItems,
            sourceDataProvider: SourceDataClient(
                fetcher: CrawlClientSocialSourceFetcher(crawlClient: context.crawlClient)
            )
        )
        let recommendationOutput = await recommendIfNeeded(
            month: rawMonth,
            enrichedCandidates: enrichedCandidates,
            configuration: recommendations
        )
        let artifacts = try writeArtifacts(
            month: rawMonth,
            sourceItems: sourceItems,
            extractionResults: extractionResults,
            potentialCandidates: potentialCandidates,
            enrichedCandidates: enrichedCandidates,
            recommendationOutput: recommendationOutput,
            runDirectory: runDirectory
        )

        return MonthlyMetalCandidateListResult(
            runID: runID,
            runDirectory: runDirectory,
            potentialCandidatesArtifactURL: artifacts.potentialCandidates,
            enrichedCandidatesArtifactURL: artifacts.enrichedCandidates,
            recommendationContextArtifactURL: artifacts.recommendationContext,
            recommendationsArtifactURL: artifacts.recommendations,
            recommendationsHTMLURL: artifacts.recommendationsHTML,
            sourceItemsArtifactURL: artifacts.sourceItems,
            sourceExtractionArtifactURL: artifacts.sourceExtraction,
            sourceItems: sourceItems,
            extractedSourceItemCount: extractionResults.count,
            extractedCandidateMentionCount: extractedCandidateMentionCount,
            potentialCandidates: potentialCandidates,
            enrichedCandidates: enrichedCandidates,
            recommendations: recommendationOutput?.artifact.recommendations ?? []
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
        enrichedCandidates: [MonthlyMetalEnrichedCandidate],
        recommendationOutput: MonthlyMetalRecommendationOutput?,
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
        let enrichedCandidatesURL = try writeArtifact(
            fileName: "monthly-metal-enriched-candidates.json",
            data: MonthlyMetalEnrichedCandidateArtifact(
                month: month,
                candidates: enrichedCandidates
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
        let recommendationContextURL = try recommendationOutput.map {
            try writeArtifact(
                fileName: "monthly-metal-recommendation-context.json",
                data: $0.context,
                runDirectory: runDirectory
            )
        }
        let recommendationsURL = try recommendationOutput.map {
            try writeArtifact(
                fileName: "monthly-metal-recommendations.json",
                data: $0.artifact,
                runDirectory: runDirectory
            )
        }
        let recommendationsHTMLURL = try recommendationOutput.map {
            try fileSystem.writeText(
                $0.html,
                fileName: "monthly-metal-recommendations.html",
                in: runDirectory
            )
        }

        return MonthlyMetalRunArtifacts(
            potentialCandidates: potentialCandidatesURL,
            enrichedCandidates: enrichedCandidatesURL,
            recommendationContext: recommendationContextURL,
            recommendations: recommendationsURL,
            recommendationsHTML: recommendationsHTMLURL,
            sourceItems: sourceItemsURL,
            sourceExtraction: sourceExtractionURL
        )
    }

    private func writeArtifact<T: Encodable>(
        fileName: String,
        data: T,
        runDirectory: URL
    ) throws -> URL {
        try fileSystem.writeJSON(data, fileName: fileName, in: runDirectory)
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

        for sourceItem in sourceItems where SourceCandidateSignalDetector.shared.shouldExtractCandidates(
            sourceKind: sourceItem.sourceKind,
            text: sourceItem.text
        ) {
            results.append(await extractor.extract(from: sourceItem))
        }

        return results
    }

    private func recommendIfNeeded(
        month: String,
        enrichedCandidates: [MonthlyMetalEnrichedCandidate],
        configuration: MonthlyMetalRecommendationConfiguration?
    ) async -> MonthlyMetalRecommendationOutput? {
        guard let configuration else {
            return nil
        }

        let context = recommendationContext(
            month: month,
            enrichedCandidates: enrichedCandidates
        )

        guard !context.candidates.isEmpty else {
            let artifact = MonthlyMetalRecommendationArtifact(
                month: month,
                model: configuration.model,
                promptVersion: LocalLLMMonthlyMetalRecommender.promptVersion,
                recommendations: [],
                rawResponse: nil,
                errorMessage: "No enriched candidates available for recommendation."
            )
            return MonthlyMetalRecommendationOutput(
                context: context,
                artifact: artifact,
                html: MonthlyMetalRecommendationHTMLRenderer().render(
                    month: month,
                    context: context,
                    artifact: artifact
                )
            )
        }

        let providerConfiguration = MonthlyMetalSourceExtractionConfiguration(
            baseURL: configuration.baseURL,
            model: configuration.model,
            temperature: configuration.temperature,
            maxTokens: configuration.maxTokens,
            requestTimeout: configuration.requestTimeout
        )
        let recommender = LocalLLMMonthlyMetalRecommender(
            provider: llmProviderFactory(providerConfiguration),
            model: configuration.model,
            temperature: configuration.temperature,
            maxTokens: configuration.maxTokens,
            limit: configuration.limit
        )
        let artifact = await recommender.recommend(
            month: month,
            context: context
        )

        return MonthlyMetalRecommendationOutput(
            context: context,
            artifact: artifact,
            html: MonthlyMetalRecommendationHTMLRenderer().render(
                month: month,
                context: context,
                artifact: artifact
            )
        )
    }

    private func recommendationContext(
        month: String,
        enrichedCandidates: [MonthlyMetalEnrichedCandidate]
    ) -> MonthlyMetalRecommendationContextArtifact {
        MonthlyMetalRecommendationContextArtifact(
            month: month,
            candidates: enrichedCandidates.map { recommendationCandidateContext(from: $0) }
        )
    }

    private func recommendationCandidateContext(
        from enrichedCandidate: MonthlyMetalEnrichedCandidate
    ) -> MonthlyMetalRecommendationCandidateContext {
        let candidate = enrichedCandidate.candidate
        let metalArchives = enrichedCandidate.metalArchives.map {
            MonthlyMetalRecommendationMetalArchivesContext(
                genre: $0.genre,
                lyricalThemes: $0.lyricalThemes,
                fullLengthAlbumCount: $0.fullLengthAlbumCount,
                reviewCount: $0.reviewCount,
                averageReviewScore: $0.averageReviewScore,
                yearsActive: $0.yearsActive,
                fullTimeMemberCount: $0.fullTimeMemberCount
            )
        }
        let bandcamp = enrichedCandidate.bandcamp.map {
            MonthlyMetalRecommendationBandcampContext(
                hasDigital: $0.hasDigital,
                digitalFormats: $0.digitalFormats,
                digitalQualityText: $0.digitalQualityText,
                isHiResAvailable: $0.isHiResAvailable,
                hasCD: $0.hasCD,
                isCDAvailable: $0.isCDAvailable,
                cdAvailabilityText: $0.cdAvailabilityText
            )
        }

        return MonthlyMetalRecommendationCandidateContext(
            bandName: candidate.bandName,
            albumTitle: candidate.albumTitle,
            releaseType: candidate.releaseType,
            releaseDateText: candidate.releaseDate
                .map { MonthlyMetalDateFormatter.shared.format($0) }
                ?? candidate.releaseDateText,
            labelName: candidate.labelName,
            metalArchivesURL: candidate.metalArchivesURL,
            bandcampURL: enrichedCandidate.bandcamp?.albumURL,
            coverImageURL: enrichedCandidate.bandcamp?.coverImageURL
                ?? enrichedCandidate.metalArchives?.coverImageURL,
            sourceCount: candidate.sources.count,
            sourceSignals: orderedUnique(candidate.sources.compactMap(\.signal)),
            sourceEvidence: orderedUnique(candidate.sources.compactMap(\.evidence)),
            metalArchives: metalArchives,
            bandcamp: bandcamp,
            issues: recommendationIssues(for: enrichedCandidate)
        )
    }

    private func recommendationIssues(
        for enrichedCandidate: MonthlyMetalEnrichedCandidate
    ) -> [String] {
        var issues: [String] = []

        switch enrichedCandidate.status {
        case .matched:
            break
        case .notFound:
            issues.append("metal_archives_not_found")
        case .failed:
            issues.append("metal_archives_failed")
        }

        switch enrichedCandidate.bandcampStatus {
        case .matched:
            break
        case .notFound:
            issues.append("bandcamp_not_found")
        case .failed:
            issues.append("bandcamp_failed")
        case nil:
            issues.append("bandcamp_not_checked")
        }

        return issues
    }

    private func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmed.isEmpty,
                  seen.insert(trimmed).inserted
            else {
                continue
            }

            result.append(trimmed)
        }

        return result
    }

    private func enrichPotentialCandidates(
        _ candidates: [MonthlyMetalCandidate],
        sourceItems: [MonthlyMetalSourceItem],
        sourceDataProvider: any SourceDataProviding
    ) async -> [MonthlyMetalEnrichedCandidate] {
        let sourceItemsByItemURL = Dictionary(
            sourceItems.compactMap { sourceItem in
                sourceItem.itemURL.map { ($0, sourceItem) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        var enrichedCandidates: [MonthlyMetalEnrichedCandidate] = []

        for candidate in candidates {
            var resolvedCandidate = candidate
            var metalArchivesStatus = MonthlyMetalEnrichmentStatus.notFound
            var metalArchives: MetalArchivesAlbumEnrichment?
            var metalArchivesErrorMessage: String?

            do {
                let enrichment = if let metalArchivesURL = candidate.metalArchivesURL {
                    try await sourceDataProvider.enrichAlbum(at: metalArchivesURL)
                } else {
                    try await sourceDataProvider.enrichAlbum(bandName: candidate.bandName, albumTitle: candidate.albumTitle)
                }

                if let enrichment {
                    resolvedCandidate = merge(candidate, with: enrichment)
                    metalArchivesStatus = .matched
                    metalArchives = enrichment
                }
            } catch {
                metalArchivesStatus = .failed
                metalArchivesErrorMessage = String(describing: error)
            }

            var bandcampStatus = MonthlyMetalEnrichmentStatus.notFound
            var bandcamp: BandcampAlbumAvailability?
            var bandcampErrorMessage: String?

            do {
                let availability = try await bandcampAvailability(
                    for: resolvedCandidate,
                    sourceItemsByItemURL: sourceItemsByItemURL,
                    sourceDataProvider: sourceDataProvider
                )

                if let availability {
                    bandcampStatus = .matched
                    bandcamp = availability
                }
            } catch {
                bandcampStatus = .failed
                bandcampErrorMessage = String(describing: error)
            }

            enrichedCandidates.append(MonthlyMetalEnrichedCandidate(
                candidate: resolvedCandidate,
                status: metalArchivesStatus,
                metalArchives: metalArchives,
                errorMessage: metalArchivesErrorMessage,
                bandcampStatus: bandcampStatus,
                bandcamp: bandcamp,
                bandcampErrorMessage: bandcampErrorMessage
            ))
        }

        return enrichedCandidates
    }

    private func bandcampAvailability(
        for candidate: MonthlyMetalCandidate,
        sourceItemsByItemURL: [URL: MonthlyMetalSourceItem],
        sourceDataProvider: any SourceDataProviding
    ) async throws -> BandcampAlbumAvailability? {
        let sourceLinks = bandcampSourceLinks(
            for: candidate,
            sourceItemsByItemURL: sourceItemsByItemURL,
            sourceDataProvider: sourceDataProvider
        )

        for sourceLink in sourceLinks where sourceLink.kind == .album || sourceLink.kind == .redirect {
            do {
                guard let availability = try await sourceDataProvider.bandcampAvailability(at: sourceLink.url),
                      bandcampAvailability(availability, matches: candidate)
                else {
                    continue
                }

                return availability
            } catch {
                continue
            }
        }

        return try await sourceDataProvider.bandcampAvailability(
            bandName: candidate.bandName,
            albumTitle: candidate.albumTitle
        )
    }

    private func bandcampSourceLinks(
        for candidate: MonthlyMetalCandidate,
        sourceItemsByItemURL: [URL: MonthlyMetalSourceItem],
        sourceDataProvider: any SourceDataProviding
    ) -> [BandcampSourceLink] {
        var seen = Set<URL>()
        var result: [BandcampSourceLink] = []

        for source in candidate.sources {
            guard let itemURL = source.itemURL,
                  let sourceItem = sourceItemsByItemURL[itemURL]
            else {
                continue
            }

            for link in sourceDataProvider.bandcampSourceLinks(
                from: sourceItem.text,
                bandName: candidate.bandName,
                albumTitle: candidate.albumTitle,
                evidence: source.evidence
            ) where seen.insert(link.url).inserted {
                result.append(link)
            }
        }

        return result
    }

    private func bandcampAvailability(
        _ availability: BandcampAlbumAvailability,
        matches candidate: MonthlyMetalCandidate
    ) -> Bool {
        if let albumTitle = availability.albumTitle,
           normalizedIdentity(albumTitle) != normalizedIdentity(candidate.albumTitle)
        {
            return false
        }

        if let bandName = availability.bandName,
           normalizedIdentity(bandName) != normalizedIdentity(candidate.bandName)
        {
            return false
        }

        return true
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
        _ candidate: MonthlyMetalCandidate,
        with enrichment: MetalArchivesAlbumEnrichment
    ) -> MonthlyMetalCandidate {
        MonthlyMetalCandidate(
            bandName: enrichment.bandName,
            albumTitle: enrichment.albumTitle,
            releaseType: enrichment.releaseType ?? candidate.releaseType,
            labelName: enrichment.labelName ?? candidate.labelName,
            releaseDate: enrichment.releaseDate ?? candidate.releaseDate,
            releaseDateText: enrichment.releaseDateText ?? candidate.releaseDateText,
            metalArchivesURL: enrichment.albumURL,
            sources: candidate.sources
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

    private func normalizedIdentity(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: "",
                options: .regularExpression
            )
    }
}

private struct MonthlyMetalPotentialCandidateArtifact: Encodable {
    let month: String
    let candidates: [MonthlyMetalCandidate]
}

private struct MonthlyMetalEnrichedCandidateArtifact: Encodable {
    let month: String
    let candidates: [MonthlyMetalEnrichedCandidate]
}

private struct MonthlyMetalSourceItemsArtifact: Encodable {
    let month: String
    let sourceItems: [MonthlyMetalSourceItem]
}

private struct MonthlyMetalRunArtifacts {
    let potentialCandidates: URL
    let enrichedCandidates: URL
    let recommendationContext: URL?
    let recommendations: URL?
    let recommendationsHTML: URL?
    let sourceItems: URL
    let sourceExtraction: URL?
}

private struct MonthlyMetalRecommendationOutput {
    let context: MonthlyMetalRecommendationContextArtifact
    let artifact: MonthlyMetalRecommendationArtifact
    let html: String
}

private struct UnavailableLLMExtractionFallback: LLMExtractionFallback {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate {
        throw MonthlyMetalError.invalidOperation("LLM extraction is not used during monthly candidate discovery.")
    }

    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft {
        throw MonthlyMetalError.invalidOperation("Bandcamp extraction is not used during monthly candidate discovery.")
    }
}
