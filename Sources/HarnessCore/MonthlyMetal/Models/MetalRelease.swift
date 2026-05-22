import Foundation

public struct MetalRelease: Codable, Hashable, Sendable {
    public let identity: ReleaseIdentity
    public var releaseDate: DateOnly?
    public var genre: String?
    public var country: CountryName?
    public var formationYear: Year?
    public var shortHistory: String?
    public var albumType: AlbumType?
    public var metalArchives: SourceLink?
    public var spotify: SourceLink?
    public var bandcamp: SourceLink?
    public var cdAvailability: AvailabilityStatus
    public var bandcampCdDigital: TernaryStatus
    public var summary: String?
    public var sources: [SourceReference]

    public init(
        identity: ReleaseIdentity,
        releaseDate: DateOnly? = nil,
        genre: String? = nil,
        country: CountryName? = nil,
        formationYear: Year? = nil,
        shortHistory: String? = nil,
        albumType: AlbumType? = nil,
        metalArchives: SourceLink? = nil,
        spotify: SourceLink? = nil,
        bandcamp: SourceLink? = nil,
        cdAvailability: AvailabilityStatus = .unknown,
        bandcampCdDigital: TernaryStatus = .unknown,
        summary: String? = nil,
        sources: [SourceReference] = []
    ) {
        self.identity = identity
        self.releaseDate = releaseDate
        self.genre = genre
        self.country = country
        self.formationYear = formationYear
        self.shortHistory = shortHistory
        self.albumType = albumType
        self.metalArchives = metalArchives
        self.spotify = spotify
        self.bandcamp = bandcamp
        self.cdAvailability = cdAvailability
        self.bandcampCdDigital = bandcampCdDigital
        self.summary = summary
        self.sources = sources
    }
}
