import Foundation

public struct SourceDataClient: SourceDataProviding {
    private let socialClient: SocialSourceClient
    private let metalArchivesAlbumExtractor: any MetalArchivesAlbumExtracting
    private let metalArchivesAlbumSearchClient: any MetalArchivesAlbumSearching

    public init(
        fetcher: any SocialSourceFetching = URLSessionSocialSourceFetcher(),
        youTubeRSSFeedParser: YouTubeRSSFeedParser = YouTubeRSSFeedParser(),
        youTubeVideoDescriptionExtractor: YouTubeVideoDescriptionExtractor = YouTubeVideoDescriptionExtractor(),
        metalArchivesAlbumExtractor: any MetalArchivesAlbumExtracting = MetalArchivesAlbumPageExtractor.shared,
        metalArchivesSearchPageSize: Int = 200,
        metalArchivesIncludedReleaseTypes: Set<String> = ["full-length", "ep"]
    ) {
        self.socialClient = SocialSourceClient(
            fetcher: fetcher,
            youTubeRSSFeedParser: youTubeRSSFeedParser,
            youTubeVideoDescriptionExtractor: youTubeVideoDescriptionExtractor
        )
        self.metalArchivesAlbumExtractor = metalArchivesAlbumExtractor
        self.metalArchivesAlbumSearchClient = MetalArchivesAdvancedAlbumSearchClient(
            fetcher: fetcher,
            pageSize: metalArchivesSearchPageSize,
            includedReleaseTypes: metalArchivesIncludedReleaseTypes
        )
    }

    public init(
        socialClient: SocialSourceClient,
        metalArchivesAlbumExtractor: any MetalArchivesAlbumExtracting,
        metalArchivesAlbumSearchClient: any MetalArchivesAlbumSearching
    ) {
        self.socialClient = socialClient
        self.metalArchivesAlbumExtractor = metalArchivesAlbumExtractor
        self.metalArchivesAlbumSearchClient = metalArchivesAlbumSearchClient
    }

    public func getDescription(
        from url: URL,
        type: SocialSourceType
    ) async throws -> String {
        try await socialClient.getDescription(from: url, type: type)
    }

    public func getDescriptions(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType,
        options: SocialSourceOptions
    ) async throws -> [String] {
        try await socialClient.getDescriptions(
            from: url,
            dateRange: dateRange,
            type: type,
            options: options
        )
    }

    public func getDescriptionItems(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType,
        options: SocialSourceOptions
    ) async throws -> [SocialSourceItem] {
        try await socialClient.getDescriptionItems(
            from: url,
            dateRange: dateRange,
            type: type,
            options: options
        )
    }

    public func extractAlbum(from page: SocialSourcePage) -> MetalArchivesAlbum? {
        metalArchivesAlbumExtractor.extractAlbum(from: page)
    }

    public func extractAlbum(
        from html: String,
        finalURL: URL?
    ) -> MetalArchivesAlbum? {
        metalArchivesAlbumExtractor.extractAlbum(from: html, finalURL: finalURL)
    }

    public func albums(
        for month: Date
    ) async throws -> [MetalArchivesAdvancedAlbumSearchResult] {
        try await metalArchivesAlbumSearchClient.albums(for: month)
    }

    public func albumURLs(for month: Date) async throws -> [URL] {
        try await metalArchivesAlbumSearchClient.albumURLs(for: month)
    }

    public func searchURL(for month: Date) -> URL {
        metalArchivesAlbumSearchClient.searchURL(for: month)
    }

    public func searchURL(
        for month: Date,
        start: Int,
        pageSize: Int
    ) -> URL {
        metalArchivesAlbumSearchClient.searchURL(
            for: month,
            start: start,
            pageSize: pageSize
        )
    }
}
