import Foundation

public struct Album: Codable, Hashable, Sendable {
    public let id: AlbumID
    public let bandID: BandID
    public let title: String
    public let type: AlbumType?
    public let releaseDate: Date?

    public init(id: AlbumID, bandID: BandID, title: String, type: AlbumType? = nil, releaseDate: Date? = nil) {
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

public struct AlbumID: Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String = UUID().uuidString) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
