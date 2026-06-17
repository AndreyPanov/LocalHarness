import Foundation

public struct MonthlyMetalScoutResult: Sendable {
    public let runID: RunID
    public let runDirectory: URL
    public let releases: [ReleaseCandidate]

    public init(runID: RunID, runDirectory: URL, releases: [ReleaseCandidate]) {
        self.runID = runID
        self.runDirectory = runDirectory
        self.releases = releases
    }
}

public struct MonthlyMetalAlbumListResult: Sendable {
    public let runID: RunID
    public let runDirectory: URL
    public let albums: [MonthlyMetalAlbumListItem]

    public init(runID: RunID, runDirectory: URL, albums: [MonthlyMetalAlbumListItem]) {
        self.runID = runID
        self.runDirectory = runDirectory
        self.albums = albums
    }
}

public struct MonthlyMetalAlbumListItem: Sendable {
    public let bandName: String
    public let albumTitle: String
    public let releaseType: String
    public let releaseDate: Date?
    public let releaseDateText: String?
    public let metalArchivesURL: URL

    public init(
        bandName: String,
        albumTitle: String,
        releaseType: String,
        releaseDate: Date?,
        releaseDateText: String?,
        metalArchivesURL: URL
    ) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.releaseType = releaseType
        self.releaseDate = releaseDate
        self.releaseDateText = releaseDateText
        self.metalArchivesURL = metalArchivesURL
    }
}

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

    public func discover(month rawMonth: String) async throws -> MonthlyMetalScoutResult {
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

        let releases = try await MetalArchivesMonthlyReleaseDiscoverySource()
            .discover(month: month, context: context)

        return MonthlyMetalScoutResult(
            runID: runID,
            runDirectory: runDirectory,
            releases: releases
        )
    }

    public func listAlbums(month rawMonth: String) async throws -> MonthlyMetalAlbumListResult {
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

        let albums = try await MetalArchivesAdvancedAlbumSearchSource()
            .albums(for: month, context: context)
            .map {
                MonthlyMetalAlbumListItem(
                    bandName: $0.bandName,
                    albumTitle: $0.albumTitle,
                    releaseType: $0.releaseType,
                    releaseDate: $0.releaseDate,
                    releaseDateText: $0.releaseDateText,
                    metalArchivesURL: $0.albumURL
                )
            }

        return MonthlyMetalAlbumListResult(
            runID: runID,
            runDirectory: runDirectory,
            albums: albums
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
}

private struct UnavailableLLMExtractionFallback: LLMExtractionFallback {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate {
        throw HarnessError.invalidAgentAction("LLM extraction is not used during Metal Archives discovery.")
    }

    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft {
        throw HarnessError.invalidAgentAction("Bandcamp extraction is not used during Metal Archives discovery.")
    }
}
