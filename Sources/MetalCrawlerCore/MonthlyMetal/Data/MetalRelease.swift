import Foundation

public struct MetalRelease: Codable, Hashable, Sendable {
    let bandName: String
    let albumTitle: String
    let releaseDate: Date?
    let genre: String?
    let country: String?
    let formationDate: Date?
    let albumType: AlbumType?
    let metalArchivesURL: URL?
    let spotifyURL: URL?
    let bandcampURL: URL?
    let cdAvailability: AvailabilityStatus
    let bandcampCdDigital: TernaryStatus
    let summary: String?
    let sources: [SourceReference]

    public init(bandName: String, albumTitle: String, releaseDate: Date?, genre: String?, country: String?, formationDate: Date?, albumType: AlbumType?, metalArchivesURL: URL?, spotifyURL: URL?, bandcampURL: URL?, cdAvailability: AvailabilityStatus, bandcampCdDigital: TernaryStatus, summary: String?, sources: [SourceReference]) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.releaseDate = releaseDate
        self.genre = genre
        self.country = country
        self.formationDate = formationDate
        self.albumType = albumType
        self.metalArchivesURL = metalArchivesURL
        self.spotifyURL = spotifyURL
        self.bandcampURL = bandcampURL
        self.cdAvailability = cdAvailability
        self.bandcampCdDigital = bandcampCdDigital
        self.summary = summary
        self.sources = sources
    }
}
