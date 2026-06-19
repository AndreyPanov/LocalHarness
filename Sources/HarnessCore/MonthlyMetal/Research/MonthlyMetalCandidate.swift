import Foundation

public struct MonthlyMetalCandidateListResult: Sendable {
    public let runID: RunID
    public let runDirectory: URL
    public let candidateArtifactURL: URL
    public let candidates: [MonthlyMetalCandidate]

    public init(
        runID: RunID,
        runDirectory: URL,
        candidateArtifactURL: URL,
        candidates: [MonthlyMetalCandidate]
    ) {
        self.runID = runID
        self.runDirectory = runDirectory
        self.candidateArtifactURL = candidateArtifactURL
        self.candidates = candidates
    }
}

public struct MonthlyMetalCandidate: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let releaseType: String?
    public let labelName: String?
    public let releaseDate: Date?
    public let releaseDateText: String?
    public let metalArchivesURL: URL?
    public let sources: [MonthlyMetalCandidateSource]

    public init(
        bandName: String,
        albumTitle: String,
        releaseType: String?,
        labelName: String?,
        releaseDate: Date?,
        releaseDateText: String?,
        metalArchivesURL: URL?,
        sources: [MonthlyMetalCandidateSource]
    ) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.releaseType = releaseType
        self.labelName = labelName
        self.releaseDate = releaseDate
        self.releaseDateText = releaseDateText
        self.metalArchivesURL = metalArchivesURL
        self.sources = sources
    }
}

public struct MonthlyMetalCandidateSource: Codable, Hashable, Sendable {
    public let name: String
    public let kind: String
    public let sourceURL: URL?
    public let itemURL: URL?
    public let rank: Int?
    public let note: String?

    public init(
        name: String,
        kind: String,
        sourceURL: URL?,
        itemURL: URL?,
        rank: Int? = nil,
        note: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.sourceURL = sourceURL
        self.itemURL = itemURL
        self.rank = rank
        self.note = note
    }
}
