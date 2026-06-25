import Foundation

public struct ReleaseCandidate: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let releaseDate: Date?
    public let country: String?
    public let genre: String?
    public let formationDate: Date?
    public let history: String?
    public let confidence: Double?
    public let sources: [SourceReference]

    public init(
        bandName: String,
        albumTitle: String,
        releaseDate: Date? = nil,
        country: String? = nil,
        genre: String? = nil,
        formationDate: Date? = nil,
        history: String? = nil,
        confidence: Double? = nil,
        sources: [SourceReference]
    ) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.releaseDate = releaseDate
        self.country = country
        self.genre = genre
        self.formationDate = formationDate
        self.history = history
        self.confidence = confidence
        self.sources = sources
    }
}
