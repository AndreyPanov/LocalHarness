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

/// Public interface for extracting album metadata from a Metal Archives album page.
public protocol MetalArchivesAlbumExtracting: Sendable {
    /// Extracts normalized album metadata from a fetched page.
    func extractAlbum(from page: SocialSourcePage) -> MetalArchivesAlbum?

    /// Extracts normalized album metadata from raw page HTML and an optional final URL.
    func extractAlbum(from html: String, finalURL: URL?) -> MetalArchivesAlbum?
}

/// Public interface for querying Metal Archives advanced album search.
public protocol MetalArchivesAlbumSearching: Sendable {
    /// Returns normalized advanced-search rows for albums released in the given month.
    func albums(for month: Date) async throws -> [MetalArchivesAdvancedAlbumSearchResult]

    /// Returns only the album URLs from advanced search for albums released in the given month.
    func albumURLs(for month: Date) async throws -> [URL]

    /// Builds the first advanced-search URL for the given month.
    func searchURL(for month: Date) -> URL

    /// Builds a paginated advanced-search URL for the given month.
    func searchURL(for month: Date, start: Int, pageSize: Int) -> URL
}

/// Single public source-provider interface exposed by this framework.
public protocol SourceDataProviding: SocialDescriptionProviding, MetalArchivesAlbumExtracting, MetalArchivesAlbumSearching {}
