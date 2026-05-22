import Foundation

public struct Album: Codable, Hashable, Sendable {
    public let id: AlbumID
    public let bandID: BandID
    public let title: String
    public let type: AlbumType?
    public let releaseDate: DateOnly?

    public init(id: AlbumID, bandID: BandID, title: String, type: AlbumType? = nil, releaseDate: DateOnly? = nil) {
        self.id = id
        self.bandID = bandID
        self.title = title
        self.type = type
        self.releaseDate = releaseDate
    }
}

public enum AlbumType: String, Codable, Hashable, Sendable {
    case fullLength = "full_length"
    case ep
    case demo
    case single
    case split
    case live
    case compilation
    case unknown
}
