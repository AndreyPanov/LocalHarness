import Foundation

public struct MonthlyMetalScout: Sendable {
    private let runsDirectory: URL
    private let knowledgeDirectory: URL
    private let runIDProvider: @Sendable () -> RunID
    private let crawlClientFactory: @Sendable (URL) -> any CrawlClient

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
    }

    init(
        runsDirectory: URL,
        knowledgeDirectory: URL,
        runIDProvider: @escaping @Sendable () -> RunID,
        crawlClientFactory: @escaping @Sendable (URL) -> any CrawlClient
    ) {
        self.runsDirectory = runsDirectory
        self.knowledgeDirectory = knowledgeDirectory
        self.runIDProvider = runIDProvider
        self.crawlClientFactory = crawlClientFactory
    }

    public func listCandidates(month rawMonth: String) async throws -> MonthlyMetalCandidateListResult {
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

        let candidatePoolBuilder = MonthlyMetalCandidatePoolBuilder(
            editorialSeedSource: EditorialReleaseSeedSource(knowledgeDirectory: knowledgeDirectory)
        )
        let candidates = try await candidatePoolBuilder.candidates(for: month, context: context)
        let candidateArtifactURL = try writeCandidateArtifact(
            month: rawMonth,
            candidates: candidates,
            runDirectory: runDirectory
        )

        return MonthlyMetalCandidateListResult(
            runID: runID,
            runDirectory: runDirectory,
            candidateArtifactURL: candidateArtifactURL,
            candidates: candidates
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
            throw HarnessError.invalidMonth(rawMonth)
        }

        return month
    }

    private func writeCandidateArtifact(
        month: String,
        candidates: [MonthlyMetalCandidate],
        runDirectory: URL
    ) throws -> URL {
        let artifactURL = runDirectory.appendingPathComponent(
            "monthly-metal-candidates.json",
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
}

private struct MonthlyMetalCandidateArtifact: Encodable {
    let month: String
    let candidates: [MonthlyMetalCandidate]
}

private struct UnavailableLLMExtractionFallback: LLMExtractionFallback {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate {
        throw HarnessError.invalidAgentAction("LLM extraction is not used during monthly candidate discovery.")
    }

    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft {
        throw HarnessError.invalidAgentAction("Bandcamp extraction is not used during monthly candidate discovery.")
    }
}
