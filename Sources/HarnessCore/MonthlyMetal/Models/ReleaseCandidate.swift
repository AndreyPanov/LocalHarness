import Foundation

public struct ReleaseCandidate: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let releaseDate: DateOnly?
    public let sources: [SourceReference]

    public init(bandName: String, albumTitle: String, releaseDate: DateOnly? = nil, sources: [SourceReference]) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.releaseDate = releaseDate
        self.sources = sources
    }
}
