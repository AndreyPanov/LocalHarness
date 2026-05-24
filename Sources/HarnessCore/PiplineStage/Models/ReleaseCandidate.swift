import Foundation

public struct ReleaseCandidate: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let releaseDate: Date?
    public let sources: [SourceReference]

    public init(bandName: String, albumTitle: String, releaseDate: Date? = nil, sources: [SourceReference]) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.releaseDate = releaseDate
        self.sources = sources
    }
}
