import Foundation

/// Supported social platforms whose post or video text can be collected.
public enum SocialSourceType: Sendable {
    case youtube
    case instagram
}

/// Normalized text collected from one social source item.
public struct SocialSourceItem: Codable, Hashable, Sendable {
    public let sourceKind: String
    public let itemURL: URL?
    public let title: String?
    public let publishedAt: Date?
    public let text: String

    public init(
        sourceKind: String,
        itemURL: URL?,
        title: String?,
        publishedAt: Date?,
        text: String
    ) {
        self.sourceKind = sourceKind
        self.itemURL = itemURL
        self.title = title
        self.publishedAt = publishedAt
        self.text = text
    }
}

/// Network request abstraction used by source fetchers.
public struct SocialSourceRequest: Sendable {
    public let url: URL
    public let headers: [String: String]
    public let sourceKind: String?

    public init(
        url: URL,
        headers: [String: String] = [:],
        sourceKind: String? = nil
    ) {
        self.url = url
        self.headers = headers
        self.sourceKind = sourceKind
    }
}

/// Network response abstraction used by source parsers.
public struct SocialSourcePage: Sendable {
    public let url: URL
    public let finalURL: URL
    public let text: String
    public let html: String?

    public init(
        url: URL,
        finalURL: URL,
        text: String,
        html: String? = nil
    ) {
        self.url = url
        self.finalURL = finalURL
        self.text = text
        self.html = html
    }
}

/// Fetches raw pages while letting callers decide whether requests are cached, live, or fixture-backed.
public protocol SocialSourceFetching: Sendable {
    /// Loads one URL and returns the raw text/HTML needed by source parsers.
    func fetch(_ request: SocialSourceRequest) async throws -> SocialSourcePage
}

/// Options for channel/profile collection.
public struct SocialSourceOptions: Sendable {
    public let youtubeChannelID: String?
    public let youtubeTitleFilters: [String]
    public let instagramMaxPages: Int

    public init(
        youtubeChannelID: String? = nil,
        youtubeTitleFilters: [String] = [],
        instagramMaxPages: Int = 12
    ) {
        self.youtubeChannelID = youtubeChannelID
        self.youtubeTitleFilters = youtubeTitleFilters
        self.instagramMaxPages = instagramMaxPages
    }
}

public enum SocialSourceError: Error, Equatable {
    case invalidDateRange(count: Int)
    case missingDescription(URL)
    case missingInstagramUsername(URL)
    case missingYouTubeChannelID(URL)
    case unsupportedDirectDescription(SocialSourceType)
}

/// Descriptor for one configured source provider, such as BangerTV or an Instagram profile.
public struct SourceProviderDescriptor: Codable, Hashable, Sendable {
    public let name: String
    public let kind: String
    public let sourceURL: URL?
    public let channelID: String?
    public let username: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case kind
        case sourceURL
        case url
        case channelID
        case username
    }

    public init(
        name: String,
        kind: String,
        sourceURL: URL?,
        channelID: String? = nil,
        username: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.sourceURL = sourceURL
        self.channelID = channelID
        self.username = username
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
            ?? container.decodeIfPresent(URL.self, forKey: .url)
        self.channelID = try container.decodeIfPresent(String.self, forKey: .channelID)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encodeIfPresent(channelID, forKey: .channelID)
        try container.encodeIfPresent(username, forKey: .username)
    }
}

/// Normalized item emitted by a configured source provider.
public struct SourceProviderItem: Codable, Hashable, Sendable {
    public let sourceName: String
    public let sourceKind: String
    public let sourceURL: URL?
    public let itemURL: URL?
    public let title: String?
    public let publishedAt: Date?
    public let text: String

    public init(
        sourceName: String,
        sourceKind: String,
        sourceURL: URL?,
        itemURL: URL?,
        title: String?,
        publishedAt: Date?,
        text: String
    ) {
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.sourceURL = sourceURL
        self.itemURL = itemURL
        self.title = title
        self.publishedAt = publishedAt
        self.text = text
    }
}

/// Normalized album details extracted from a Metal Archives album page.
public struct MetalArchivesAlbum: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let albumURL: URL?
    public let releaseType: String?
    public let labelName: String?
    public let releaseDate: Date?
    public let releaseDateText: String?

    public init(
        bandName: String,
        albumTitle: String,
        albumURL: URL?,
        releaseType: String?,
        labelName: String?,
        releaseDate: Date?,
        releaseDateText: String?
    ) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.albumURL = albumURL
        self.releaseType = releaseType
        self.labelName = labelName
        self.releaseDate = releaseDate
        self.releaseDateText = releaseDateText
    }
}

/// Raw Metal Archives advanced album search response.
public struct MetalArchivesAdvancedAlbumSearchResponse: Decodable, Sendable {
    public let iTotalRecords: Int
    public let iTotalDisplayRecords: Int
    public let aaData: [[String]]
}

/// Normalized row from the Metal Archives advanced album search endpoint.
public struct MetalArchivesAdvancedAlbumSearchResult: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let albumURL: URL
    public let releaseType: String
    public let releaseDate: Date?
    public let releaseDateText: String?

    public init(
        bandName: String,
        albumTitle: String,
        albumURL: URL,
        releaseType: String,
        releaseDate: Date?,
        releaseDateText: String?
    ) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.albumURL = albumURL
        self.releaseType = releaseType
        self.releaseDate = releaseDate
        self.releaseDateText = releaseDateText
    }
}

/// Review metadata exposed by Metal Archives for an album.
public struct MetalArchivesReviewSummary: Codable, Hashable, Sendable {
    public let reviewCount: Int?
    public let averageScore: Double?

    public init(
        reviewCount: Int?,
        averageScore: Double?
    ) {
        self.reviewCount = reviewCount
        self.averageScore = averageScore
    }
}

/// Album and band facts collected from Metal Archives for recommendation context.
public struct MetalArchivesAlbumEnrichment: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let albumURL: URL
    public let bandURL: URL?
    public let releaseType: String?
    public let releaseDate: Date?
    public let releaseDateText: String?
    public let labelName: String?
    public let genre: String?
    public let lyricalThemes: String?
    public let fullLengthAlbumCount: Int?
    public let reviewCount: Int?
    public let averageReviewScore: Double?
    public let yearsActive: Int?
    public let fullTimeMemberCount: Int?

    public init(
        bandName: String,
        albumTitle: String,
        albumURL: URL,
        bandURL: URL?,
        releaseType: String?,
        releaseDate: Date?,
        releaseDateText: String?,
        labelName: String?,
        genre: String?,
        lyricalThemes: String?,
        fullLengthAlbumCount: Int?,
        reviewCount: Int?,
        averageReviewScore: Double?,
        yearsActive: Int?,
        fullTimeMemberCount: Int?
    ) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.albumURL = albumURL
        self.bandURL = bandURL
        self.releaseType = releaseType
        self.releaseDate = releaseDate
        self.releaseDateText = releaseDateText
        self.labelName = labelName
        self.genre = genre
        self.lyricalThemes = lyricalThemes
        self.fullLengthAlbumCount = fullLengthAlbumCount
        self.reviewCount = reviewCount
        self.averageReviewScore = averageReviewScore
        self.yearsActive = yearsActive
        self.fullTimeMemberCount = fullTimeMemberCount
    }
}

/// Band-page facts extracted before they are merged into album enrichment.
public struct MetalArchivesBandEnrichment: Codable, Hashable, Sendable {
    public let bandURL: URL?
    public let genre: String?
    public let lyricalThemes: String?
    public let yearsActive: Int?
    public let fullTimeMemberCount: Int?
    public let discographyURL: URL?

    public init(
        bandURL: URL?,
        genre: String?,
        lyricalThemes: String?,
        yearsActive: Int?,
        fullTimeMemberCount: Int?,
        discographyURL: URL?
    ) {
        self.bandURL = bandURL
        self.genre = genre
        self.lyricalThemes = lyricalThemes
        self.yearsActive = yearsActive
        self.fullTimeMemberCount = fullTimeMemberCount
        self.discographyURL = discographyURL
    }
}

public enum MetalArchivesError: Error, Equatable {
    case missingAlbumHTML(URL)
    case invalidSearchResponse(URL)
}

/// Public interface for extracting textual descriptions from social platforms.
public protocol SocialDescriptionProviding: Sendable {
    /// Returns the description text for a direct social item URL, such as a YouTube video URL.
    func getDescription(
        from url: URL,
        type: SocialSourceType
    ) async throws -> String

    /// Returns only description/caption text for channel or profile items published inside a date range.
    ///
    /// This is the clean default interface for callers that do not need source-specific options.
    func getDescriptions(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType
    ) async throws -> [String]

    /// Returns only description/caption text for channel or profile items published inside a date range.
    ///
    /// The `dateRange` argument must contain exactly two dates. Their order does not matter.
    func getDescriptions(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType,
        options: SocialSourceOptions
    ) async throws -> [String]

    /// Returns description/caption text plus stable source metadata for channel or profile items.
    ///
    /// This is the clean default interface for callers that do not need source-specific options.
    func getDescriptionItems(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType
    ) async throws -> [SocialSourceItem]

    /// Returns description/caption text plus stable source metadata for channel or profile items.
    ///
    /// Use this when downstream code needs provenance such as item URL, title, publication date, or platform kind.
    func getDescriptionItems(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType,
        options: SocialSourceOptions
    ) async throws -> [SocialSourceItem]
}

public extension SocialDescriptionProviding {
    func getDescriptions(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType
    ) async throws -> [String] {
        try await getDescriptions(
            from: url,
            dateRange: dateRange,
            type: type,
            options: SocialSourceOptions()
        )
    }

    func getDescriptionItems(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType
    ) async throws -> [SocialSourceItem] {
        try await getDescriptionItems(
            from: url,
            dateRange: dateRange,
            type: type,
            options: SocialSourceOptions()
        )
    }
}

/// Public interface for configured source providers such as BangerTV and Instagram profiles.
public protocol SourceItemProviding: Sendable {
    /// Returns normalized source items from a configured provider for the requested month.
    func sourceItems(
        for month: Date,
        descriptor: SourceProviderDescriptor
    ) async throws -> [SourceProviderItem]
}

/// Public interface for deciding whether a source item is worth sending to candidate extraction.
public protocol SourceCandidateSignalFiltering: Sendable {
    /// Returns true when the source item likely contains album candidates.
    func shouldExtractCandidates(from item: SourceProviderItem) -> Bool

    /// Returns true when source text of the given kind likely contains album candidates.
    func shouldExtractCandidates(sourceKind: String, text: String) -> Bool
}

/// Public interface for extracting album metadata from a Metal Archives album page.
public protocol MetalArchivesAlbumExtracting: Sendable {
    /// Extracts normalized album metadata from a fetched page.
    func extractAlbum(from page: SocialSourcePage) -> MetalArchivesAlbum?

    /// Extracts normalized album metadata from raw page HTML and an optional final URL.
    func extractAlbum(from html: String, finalURL: URL?) -> MetalArchivesAlbum?
}

/// Public interface for strict Metal Archives enrichment parsing.
public protocol MetalArchivesEnrichmentExtracting: Sendable {
    /// Extracts album-page enrichment fields, including the linked band URL and review summary.
    func extractAlbumEnrichment(from page: SocialSourcePage) -> MetalArchivesAlbumEnrichment?

    /// Extracts album-page enrichment fields from raw HTML.
    func extractAlbumEnrichment(from html: String, finalURL: URL?) -> MetalArchivesAlbumEnrichment?

    /// Extracts band-page enrichment fields such as genre, themes, active years, and current members.
    func extractBandEnrichment(from page: SocialSourcePage) -> MetalArchivesBandEnrichment?

    /// Extracts band-page enrichment fields from raw HTML.
    func extractBandEnrichment(from html: String, finalURL: URL?) -> MetalArchivesBandEnrichment?

    /// Counts full-length albums from a Metal Archives discography table response.
    func fullLengthAlbumCount(fromDiscographyHTML html: String) -> Int?
}

/// Public interface for querying Metal Archives advanced album search.
public protocol MetalArchivesAlbumSearching: Sendable {
    /// Returns normalized advanced-search rows for albums released in the given month.
    func albums(for month: Date) async throws -> [MetalArchivesAdvancedAlbumSearchResult]

    /// Returns only the album URLs from advanced search for albums released in the given month.
    func albumURLs(for month: Date) async throws -> [URL]

    /// Returns normalized advanced-search rows matching the given band and album title.
    func albums(
        bandName: String,
        albumTitle: String,
        limit: Int
    ) async throws -> [MetalArchivesAdvancedAlbumSearchResult]

    /// Builds the first advanced-search URL for the given month.
    func searchURL(for month: Date) -> URL

    /// Builds a paginated advanced-search URL for the given month.
    func searchURL(for month: Date, start: Int, pageSize: Int) -> URL

    /// Builds a paginated advanced-search URL for a band and album title lookup.
    func searchURL(
        bandName: String,
        albumTitle: String,
        start: Int,
        pageSize: Int
    ) -> URL
}

/// Public interface for resolving and enriching Metal Archives albums.
public protocol MetalArchivesAlbumEnriching: Sendable {
    /// Resolves an exact band/album title pair and returns merged album and band facts.
    func enrichAlbum(
        bandName: String,
        albumTitle: String
    ) async throws -> MetalArchivesAlbumEnrichment?

    /// Fetches and enriches a known Metal Archives album URL.
    func enrichAlbum(at albumURL: URL) async throws -> MetalArchivesAlbumEnrichment?
}

/// Single public source-provider interface exposed by this framework.
public protocol SourceDataProviding: SocialDescriptionProviding, SourceItemProviding, SourceCandidateSignalFiltering, MetalArchivesAlbumExtracting, MetalArchivesEnrichmentExtracting, MetalArchivesAlbumSearching, MetalArchivesAlbumEnriching {}
