import Foundation
import LocalLLMKit

public struct MonthlyMetalSourceExtractionConfiguration: Sendable {
    public let baseURL: URL
    public let model: String
    public let temperature: Double
    public let maxTokens: Int
    public let requestTimeout: TimeInterval

    public init(
        baseURL: URL = LocalLLMModelPreset.sourceExtraction14B.baseURL,
        model: String = LocalLLMModelPreset.sourceExtraction14B.model,
        temperature: Double = 0,
        maxTokens: Int = 8192,
        requestTimeout: TimeInterval = 300
    ) {
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.requestTimeout = requestTimeout
    }
}

public struct MonthlyMetalSourceExtractionArtifact: Codable, Hashable, Sendable {
    public let month: String
    public let results: [MonthlyMetalSourceExtractionResult]

    public init(month: String, results: [MonthlyMetalSourceExtractionResult]) {
        self.month = month
        self.results = results
    }
}

public struct MonthlyMetalSourceExtractionResult: Codable, Hashable, Sendable {
    public let sourceName: String
    public let sourceKind: String
    public let sourceURL: URL?
    public let itemURL: URL?
    public let title: String?
    public let publishedAt: Date?
    public let candidates: [MonthlyMetalExtractedSourceCandidate]
    public let rawResponse: String?
    public let errorMessage: String?

    public init(
        sourceName: String,
        sourceKind: String,
        sourceURL: URL?,
        itemURL: URL?,
        title: String?,
        publishedAt: Date?,
        candidates: [MonthlyMetalExtractedSourceCandidate],
        rawResponse: String?,
        errorMessage: String?
    ) {
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.sourceURL = sourceURL
        self.itemURL = itemURL
        self.title = title
        self.publishedAt = publishedAt
        self.candidates = candidates
        self.rawResponse = rawResponse
        self.errorMessage = errorMessage
    }
}

public struct MonthlyMetalExtractedSourceCandidate: Codable, Hashable, Sendable {
    public let bandName: String
    public let albumTitle: String
    public let sourceSignal: String
    public let labelName: String?
    public let releaseDateText: String?
    public let evidence: String
    public let confidence: Double

    public init(
        bandName: String,
        albumTitle: String,
        sourceSignal: String,
        labelName: String?,
        releaseDateText: String?,
        evidence: String,
        confidence: Double
    ) {
        self.bandName = bandName
        self.albumTitle = albumTitle
        self.sourceSignal = sourceSignal
        self.labelName = labelName
        self.releaseDateText = releaseDateText
        self.evidence = evidence
        self.confidence = confidence
    }
}
