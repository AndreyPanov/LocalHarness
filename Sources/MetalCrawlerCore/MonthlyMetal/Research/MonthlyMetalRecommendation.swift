import Foundation
import LocalLLMKit

public struct MonthlyMetalRecommendationConfiguration: Sendable {
    public let baseURL: URL
    public let model: String
    public let temperature: Double
    public let maxTokens: Int
    public let requestTimeout: TimeInterval
    public let limit: Int

    public init(
        baseURL: URL = LocalLLMModelPreset.recommendations120B.baseURL,
        model: String = LocalLLMModelPreset.recommendations120B.model,
        temperature: Double = 0.2,
        maxTokens: Int = 8192,
        requestTimeout: TimeInterval = 900,
        limit: Int = 30
    ) {
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.requestTimeout = requestTimeout
        self.limit = limit
    }
}

public struct MonthlyMetalRecommendationContextArtifact: Codable, Hashable, Sendable {
    public let month: String
    public let candidates: [MonthlyMetalRecommendationCandidateContext]

    public init(
        month: String,
        candidates: [MonthlyMetalRecommendationCandidateContext]
    ) {
        self.month = month
        self.candidates = candidates
    }
}

public struct MonthlyMetalRecommendationCandidateContext: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let releaseType: String?
    public let releaseDateText: String?
    public let labelName: String?
    public let metalArchivesURL: URL?
    public let bandcampURL: URL?
    public let coverImageURL: URL?
    public let sourceCount: Int
    public let sourceSignals: [String]
    public let sourceEvidence: [String]
    public let metalArchives: MonthlyMetalRecommendationMetalArchivesContext?
    public let bandcamp: MonthlyMetalRecommendationBandcampContext?
    public let issues: [String]

    public init(
        bandName: String,
        albumTitle: String,
        releaseType: String?,
        releaseDateText: String?,
        labelName: String?,
        metalArchivesURL: URL?,
        bandcampURL: URL?,
        coverImageURL: URL?,
        sourceCount: Int,
        sourceSignals: [String],
        sourceEvidence: [String],
        metalArchives: MonthlyMetalRecommendationMetalArchivesContext?,
        bandcamp: MonthlyMetalRecommendationBandcampContext?,
        issues: [String]
    ) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.releaseType = releaseType
        self.releaseDateText = releaseDateText
        self.labelName = labelName
        self.metalArchivesURL = metalArchivesURL
        self.bandcampURL = bandcampURL
        self.coverImageURL = coverImageURL
        self.sourceCount = sourceCount
        self.sourceSignals = sourceSignals
        self.sourceEvidence = sourceEvidence
        self.metalArchives = metalArchives
        self.bandcamp = bandcamp
        self.issues = issues
    }
}

public struct MonthlyMetalRecommendationMetalArchivesContext: Codable, Hashable, Sendable {
    public let genre: String?
    public let lyricalThemes: String?
    public let fullLengthAlbumCount: Int?
    public let reviewCount: Int?
    public let averageReviewScore: Double?
    public let yearsActive: Int?
    public let fullTimeMemberCount: Int?

    public init(
        genre: String?,
        lyricalThemes: String?,
        fullLengthAlbumCount: Int?,
        reviewCount: Int?,
        averageReviewScore: Double?,
        yearsActive: Int?,
        fullTimeMemberCount: Int?
    ) {
        self.genre = genre
        self.lyricalThemes = lyricalThemes
        self.fullLengthAlbumCount = fullLengthAlbumCount
        self.reviewCount = reviewCount
        self.averageReviewScore = averageReviewScore
        self.yearsActive = yearsActive
        self.fullTimeMemberCount = fullTimeMemberCount
    }
}

public struct MonthlyMetalRecommendationBandcampContext: Codable, Hashable, Sendable {
    public let hasDigital: Bool
    public let digitalFormats: [String]
    public let digitalQualityText: String?
    public let isHiResAvailable: Bool?
    public let hasCD: Bool
    public let isCDAvailable: Bool
    public let cdAvailabilityText: String?

    public init(
        hasDigital: Bool,
        digitalFormats: [String],
        digitalQualityText: String?,
        isHiResAvailable: Bool?,
        hasCD: Bool,
        isCDAvailable: Bool,
        cdAvailabilityText: String?
    ) {
        self.hasDigital = hasDigital
        self.digitalFormats = digitalFormats
        self.digitalQualityText = digitalQualityText
        self.isHiResAvailable = isHiResAvailable
        self.hasCD = hasCD
        self.isCDAvailable = isCDAvailable
        self.cdAvailabilityText = cdAvailabilityText
    }
}

public enum MonthlyMetalRecommendationDecision: String, Codable, Hashable, Sendable {
    case mustCheck = "must_check"
    case likelyInteresting = "likely_interesting"
    case maybe
    case skip
}

public struct MonthlyMetalRecommendation: Codable, Hashable, Sendable {
    public let rank: Int
    public let bandName: String
    public let albumTitle: String
    public let decision: MonthlyMetalRecommendationDecision
    public let confidence: Double
    public let fitReasons: [String]
    public let cautionReasons: [String]
    public let purchaseNotes: String?
    public let evidence: [String]

    public init(
        rank: Int,
        bandName: String,
        albumTitle: String,
        decision: MonthlyMetalRecommendationDecision,
        confidence: Double,
        fitReasons: [String],
        cautionReasons: [String],
        purchaseNotes: String?,
        evidence: [String]
    ) {
        self.rank = rank
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.decision = decision
        self.confidence = confidence
        self.fitReasons = fitReasons
        self.cautionReasons = cautionReasons
        self.purchaseNotes = purchaseNotes
        self.evidence = evidence
    }
}

public struct MonthlyMetalRecommendationArtifact: Codable, Hashable, Sendable {
    public let month: String
    public let model: String
    public let promptVersion: String
    public let recommendations: [MonthlyMetalRecommendation]
    public let rawResponse: String?
    public let errorMessage: String?

    public init(
        month: String,
        model: String,
        promptVersion: String,
        recommendations: [MonthlyMetalRecommendation],
        rawResponse: String?,
        errorMessage: String?
    ) {
        self.month = month
        self.model = model
        self.promptVersion = promptVersion
        self.recommendations = recommendations
        self.rawResponse = rawResponse
        self.errorMessage = errorMessage
    }
}
