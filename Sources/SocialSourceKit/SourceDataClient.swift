import Foundation

public struct SourceDataClient: SourceDataProviding {
    private let socialClient: SocialSourceClient
    private let metalArchivesAlbumExtractor: any MetalArchivesAlbumExtracting & MetalArchivesEnrichmentExtracting
    private let metalArchivesAlbumSearchClient: any MetalArchivesAlbumSearching
    private let metalArchivesAlbumEnrichmentClient: any MetalArchivesAlbumEnriching
    private let bandcampAlbumAvailabilityExtractor: any BandcampAlbumAvailabilityExtracting
    private let bandcampSourceLinkExtractor: any BandcampSourceLinkExtracting
    private let bandcampAlbumSearchClient: any BandcampAlbumSearching
    private let bandcampAvailabilityClient: any BandcampAvailabilityChecking

    public init(
        fetcher: any SocialSourceFetching = URLSessionSocialSourceFetcher(),
        youTubeRSSFeedParser: YouTubeRSSFeedParser = YouTubeRSSFeedParser(),
        youTubeVideoDescriptionExtractor: YouTubeVideoDescriptionExtractor = YouTubeVideoDescriptionExtractor(),
        metalArchivesAlbumExtractor: any MetalArchivesAlbumExtracting & MetalArchivesEnrichmentExtracting = MetalArchivesAlbumPageExtractor.shared,
        metalArchivesSearchPageSize: Int = 200,
        metalArchivesIncludedReleaseTypes: Set<String> = ["full-length", "ep"],
        bandcampAlbumAvailabilityExtractor: any BandcampAlbumAvailabilityExtracting = BandcampAlbumPageExtractor.shared,
        bandcampSourceLinkExtractor: any BandcampSourceLinkExtracting = BandcampSourceLinkExtractor()
    ) {
        self.socialClient = SocialSourceClient(
            fetcher: fetcher,
            youTubeRSSFeedParser: youTubeRSSFeedParser,
            youTubeVideoDescriptionExtractor: youTubeVideoDescriptionExtractor
        )
        self.metalArchivesAlbumExtractor = metalArchivesAlbumExtractor
        let searchClient = MetalArchivesAdvancedAlbumSearchClient(
            fetcher: fetcher,
            pageSize: metalArchivesSearchPageSize,
            includedReleaseTypes: metalArchivesIncludedReleaseTypes
        )
        self.metalArchivesAlbumSearchClient = searchClient
        self.metalArchivesAlbumEnrichmentClient = MetalArchivesEnrichmentClient(
            fetcher: fetcher,
            extractor: metalArchivesAlbumExtractor,
            searchClient: searchClient
        )
        self.bandcampAlbumAvailabilityExtractor = bandcampAlbumAvailabilityExtractor
        self.bandcampSourceLinkExtractor = bandcampSourceLinkExtractor
        let bandcampSearchClient = BandcampSearchClient(fetcher: fetcher)
        self.bandcampAlbumSearchClient = bandcampSearchClient
        self.bandcampAvailabilityClient = BandcampAvailabilityClient(
            fetcher: fetcher,
            searchClient: bandcampSearchClient,
            extractor: bandcampAlbumAvailabilityExtractor
        )
    }

    public init(
        socialClient: SocialSourceClient,
        metalArchivesAlbumExtractor: any MetalArchivesAlbumExtracting & MetalArchivesEnrichmentExtracting,
        metalArchivesAlbumSearchClient: any MetalArchivesAlbumSearching,
        metalArchivesAlbumEnrichmentClient: any MetalArchivesAlbumEnriching,
        bandcampAlbumAvailabilityExtractor: any BandcampAlbumAvailabilityExtracting,
        bandcampSourceLinkExtractor: any BandcampSourceLinkExtracting,
        bandcampAlbumSearchClient: any BandcampAlbumSearching,
        bandcampAvailabilityClient: any BandcampAvailabilityChecking
    ) {
        self.socialClient = socialClient
        self.metalArchivesAlbumExtractor = metalArchivesAlbumExtractor
        self.metalArchivesAlbumSearchClient = metalArchivesAlbumSearchClient
        self.metalArchivesAlbumEnrichmentClient = metalArchivesAlbumEnrichmentClient
        self.bandcampAlbumAvailabilityExtractor = bandcampAlbumAvailabilityExtractor
        self.bandcampSourceLinkExtractor = bandcampSourceLinkExtractor
        self.bandcampAlbumSearchClient = bandcampAlbumSearchClient
        self.bandcampAvailabilityClient = bandcampAvailabilityClient
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

    public func sourceItems(
        for month: Date,
        descriptor: SourceProviderDescriptor
    ) async throws -> [SourceProviderItem] {
        switch descriptor.kind {
        case "youtube_channel":
            return try await BangerTVSourceProvider(
                sourceProvider: socialClient
            ).sourceItems(for: month, descriptor: descriptor)

        case "instagram_profile":
            return try await InstagramProfileSourceProvider(
                sourceProvider: socialClient
            ).sourceItems(for: month, descriptor: descriptor)

        default:
            return []
        }
    }

    public func shouldExtractCandidates(from item: SourceProviderItem) -> Bool {
        SourceCandidateSignalDetector.shared.shouldExtractCandidates(from: item)
    }

    public func shouldExtractCandidates(sourceKind: String, text: String) -> Bool {
        SourceCandidateSignalDetector.shared.shouldExtractCandidates(
            sourceKind: sourceKind,
            text: text
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

    public func extractAlbumEnrichment(from page: SocialSourcePage) -> MetalArchivesAlbumEnrichment? {
        metalArchivesAlbumExtractor.extractAlbumEnrichment(from: page)
    }

    public func extractAlbumEnrichment(
        from html: String,
        finalURL: URL?
    ) -> MetalArchivesAlbumEnrichment? {
        metalArchivesAlbumExtractor.extractAlbumEnrichment(from: html, finalURL: finalURL)
    }

    public func extractBandEnrichment(from page: SocialSourcePage) -> MetalArchivesBandEnrichment? {
        metalArchivesAlbumExtractor.extractBandEnrichment(from: page)
    }

    public func extractBandEnrichment(
        from html: String,
        finalURL: URL?
    ) -> MetalArchivesBandEnrichment? {
        metalArchivesAlbumExtractor.extractBandEnrichment(from: html, finalURL: finalURL)
    }

    public func fullLengthAlbumCount(fromDiscographyHTML html: String) -> Int? {
        metalArchivesAlbumExtractor.fullLengthAlbumCount(fromDiscographyHTML: html)
    }

    public func albums(
        for month: Date
    ) async throws -> [MetalArchivesAdvancedAlbumSearchResult] {
        try await metalArchivesAlbumSearchClient.albums(for: month)
    }

    public func albumURLs(for month: Date) async throws -> [URL] {
        try await metalArchivesAlbumSearchClient.albumURLs(for: month)
    }

    public func albums(
        bandName: String,
        albumTitle: String,
        limit: Int
    ) async throws -> [MetalArchivesAdvancedAlbumSearchResult] {
        try await metalArchivesAlbumSearchClient.albums(
            bandName: bandName,
            albumTitle: albumTitle,
            limit: limit
        )
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

    public func searchURL(
        bandName: String,
        albumTitle: String,
        start: Int,
        pageSize: Int
    ) -> URL {
        metalArchivesAlbumSearchClient.searchURL(
            bandName: bandName,
            albumTitle: albumTitle,
            start: start,
            pageSize: pageSize
        )
    }

    public func enrichAlbum(
        bandName: String,
        albumTitle: String
    ) async throws -> MetalArchivesAlbumEnrichment? {
        try await metalArchivesAlbumEnrichmentClient.enrichAlbum(
            bandName: bandName,
            albumTitle: albumTitle
        )
    }

    public func enrichAlbum(at albumURL: URL) async throws -> MetalArchivesAlbumEnrichment? {
        try await metalArchivesAlbumEnrichmentClient.enrichAlbum(at: albumURL)
    }

    public func extractBandcampAvailability(from page: SocialSourcePage) -> BandcampAlbumAvailability? {
        bandcampAlbumAvailabilityExtractor.extractBandcampAvailability(from: page)
    }

    public func extractBandcampAvailability(
        from html: String,
        finalURL: URL?
    ) -> BandcampAlbumAvailability? {
        bandcampAlbumAvailabilityExtractor.extractBandcampAvailability(
            from: html,
            finalURL: finalURL
        )
    }

    public func bandcampSourceLinks(from text: String) -> [BandcampSourceLink] {
        bandcampSourceLinkExtractor.bandcampSourceLinks(from: text)
    }

    public func bandcampSourceLinks(
        from text: String,
        bandName: String,
        albumTitle: String,
        evidence: String?
    ) -> [BandcampSourceLink] {
        bandcampSourceLinkExtractor.bandcampSourceLinks(
            from: text,
            bandName: bandName,
            albumTitle: albumTitle,
            evidence: evidence
        )
    }

    public func bandcampAlbums(
        bandName: String,
        albumTitle: String,
        limit: Int
    ) async throws -> [BandcampSearchResult] {
        try await bandcampAlbumSearchClient.bandcampAlbums(
            bandName: bandName,
            albumTitle: albumTitle,
            limit: limit
        )
    }

    public func bandcampSearchURL(
        bandName: String,
        albumTitle: String
    ) -> URL {
        bandcampAlbumSearchClient.bandcampSearchURL(
            bandName: bandName,
            albumTitle: albumTitle
        )
    }

    public func bandcampAvailability(
        bandName: String,
        albumTitle: String
    ) async throws -> BandcampAlbumAvailability? {
        try await bandcampAvailabilityClient.bandcampAvailability(
            bandName: bandName,
            albumTitle: albumTitle
        )
    }

    public func bandcampAvailability(at albumURL: URL) async throws -> BandcampAlbumAvailability? {
        try await bandcampAvailabilityClient.bandcampAvailability(at: albumURL)
    }
}
