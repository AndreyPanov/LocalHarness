import Foundation
import SocialSourceKit

public struct MonthlyMetalCandidateListResult: Sendable {
    public let runID: RunID
    public let runDirectory: URL
    public let potentialCandidatesArtifactURL: URL
    public let enrichedCandidatesArtifactURL: URL
    public let sourceItemsArtifactURL: URL
    public let sourceExtractionArtifactURL: URL?
    public let sourceItems: [MonthlyMetalSourceItem]
    public let extractedSourceItemCount: Int
    public let extractedCandidateMentionCount: Int
    public let potentialCandidates: [MonthlyMetalCandidate]
    public let enrichedCandidates: [MonthlyMetalEnrichedCandidate]

    public init(
        runID: RunID,
        runDirectory: URL,
        potentialCandidatesArtifactURL: URL,
        enrichedCandidatesArtifactURL: URL,
        sourceItemsArtifactURL: URL,
        sourceExtractionArtifactURL: URL? = nil,
        sourceItems: [MonthlyMetalSourceItem],
        extractedSourceItemCount: Int,
        extractedCandidateMentionCount: Int,
        potentialCandidates: [MonthlyMetalCandidate],
        enrichedCandidates: [MonthlyMetalEnrichedCandidate]
    ) {
        self.runID = runID
        self.runDirectory = runDirectory
        self.potentialCandidatesArtifactURL = potentialCandidatesArtifactURL
        self.enrichedCandidatesArtifactURL = enrichedCandidatesArtifactURL
        self.sourceItemsArtifactURL = sourceItemsArtifactURL
        self.sourceExtractionArtifactURL = sourceExtractionArtifactURL
        self.sourceItems = sourceItems
        self.extractedSourceItemCount = extractedSourceItemCount
        self.extractedCandidateMentionCount = extractedCandidateMentionCount
        self.potentialCandidates = potentialCandidates
        self.enrichedCandidates = enrichedCandidates
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
    public let signal: String?
    public let evidence: String?
    public let confidence: Double?

    public init(
        name: String,
        kind: String,
        sourceURL: URL?,
        itemURL: URL?,
        rank: Int? = nil,
        note: String? = nil,
        signal: String? = nil,
        evidence: String? = nil,
        confidence: Double? = nil
    ) {
        self.name = name
        self.kind = kind
        self.sourceURL = sourceURL
        self.itemURL = itemURL
        self.rank = rank
        self.note = note
        self.signal = signal
        self.evidence = evidence
        self.confidence = confidence
    }
}

public enum MonthlyMetalEnrichmentStatus: String, Codable, Hashable, Sendable {
    case matched
    case notFound = "not_found"
    case failed
}

public struct MonthlyMetalEnrichedCandidate: Codable, Hashable, Sendable {
    public let candidate: MonthlyMetalCandidate
    public let status: MonthlyMetalEnrichmentStatus
    public let metalArchives: MetalArchivesAlbumEnrichment?
    public let errorMessage: String?

    public init(
        candidate: MonthlyMetalCandidate,
        status: MonthlyMetalEnrichmentStatus,
        metalArchives: MetalArchivesAlbumEnrichment?,
        errorMessage: String?
    ) {
        self.candidate = candidate
        self.status = status
        self.metalArchives = metalArchives
        self.errorMessage = errorMessage
    }
}
