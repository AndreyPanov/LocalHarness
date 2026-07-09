import Foundation
import LocalLLMKit
import Testing
@testable import MetalCrawlerCore

@Test func localLLMMonthlyMetalRecommenderRepairsInvalidJSON() async throws {
    let provider = SequentialRecommendationStubLLMProvider(responses: [
        """
        {
          "recommendations": [
            {
              "rank": 1,
              "bandName": "Invented Band",
              "albumTitle": "Invented Album",
              "decision": "must_check",
              "confidence": 0.9,
              "fitReasons": ["This album was not in the input."],
              "cautionReasons": [],
              "purchaseNotes": null,
              "evidence": ["Invented evidence"]
            }
          ]
        }
        """,
        """
        {
          "recommendations": [
            {
              "rank": 1,
              "bandName": "Lamp of Murmuur",
              "albumTitle": "The Dreaming Prince in Ecstasy",
              "decision": "must_check",
              "confidence": 0.88,
              "fitReasons": [
                "Raw black metal genre and strong review score match the high-signal discovery profile."
              ],
              "cautionReasons": [],
              "purchaseNotes": "Bandcamp has FLAC and an available CD.",
              "evidence": [
                "Genre: Raw Black Metal",
                "Bandcamp: FLAC and CD available"
              ]
            }
          ]
        }
        """
    ])
    let recommender = LocalLLMMonthlyMetalRecommender(
        provider: provider,
        model: "stub-recommendation-model",
        limit: 20
    )

    let artifact = await recommender.recommend(
        month: "2026-06",
        context: recommendationContext()
    )

    #expect(artifact.errorMessage == nil)
    #expect(artifact.recommendations.count == 1)
    #expect(artifact.recommendations.first?.bandName == "Lamp of Murmuur")
    #expect(artifact.recommendations.first?.decision == .mustCheck)
    #expect(artifact.rawResponse?.contains("--- initial response ---") == true)
    #expect(artifact.rawResponse?.contains("--- repair response ---") == true)
    #expect(await provider.requestCount() == 2)
}

@Test func monthlyMetalRecommendationHTMLRendererIncludesCoverAndReasons() throws {
    let context = recommendationContext()
    let artifact = MonthlyMetalRecommendationArtifact(
        month: "2026-06",
        model: "stub-recommendation-model",
        promptVersion: "test-prompt",
        recommendations: [
            MonthlyMetalRecommendation(
                rank: 1,
                bandName: "Lamp of Murmuur",
                albumTitle: "The Dreaming Prince in Ecstasy",
                decision: .mustCheck,
                confidence: 0.88,
                fitReasons: ["Raw black metal genre and strong review score match the profile."],
                cautionReasons: ["Only two reviews are available."],
                purchaseNotes: "Bandcamp has FLAC and an available CD.",
                evidence: ["Genre: Raw Black Metal"]
            )
        ],
        rawResponse: nil,
        errorMessage: nil
    )

    let html = MonthlyMetalRecommendationHTMLRenderer().render(
        month: "2026-06",
        context: context,
        artifact: artifact
    )

    #expect(html.contains("Monthly Metal Recommendations - 2026-06"))
    #expect(html.contains("https://example.com/cover.jpg"))
    #expect(html.contains("Raw black metal genre and strong review score"))
    #expect(html.contains("Bandcamp has FLAC and an available CD."))
    #expect(html.contains("https://lampofmurmuur.bandcamp.com/album/the-dreaming-prince-in-ecstasy"))
}

private func recommendationContext() -> MonthlyMetalRecommendationContextArtifact {
    MonthlyMetalRecommendationContextArtifact(
        month: "2026-06",
        candidates: [
            MonthlyMetalRecommendationCandidateContext(
                bandName: "Lamp of Murmuur",
                albumTitle: "The Dreaming Prince in Ecstasy",
                releaseType: "Full-length",
                releaseDateText: "2025-11-14",
                labelName: "Wolves of Hades",
                metalArchivesURL: URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559"),
                bandcampURL: URL(string: "https://lampofmurmuur.bandcamp.com/album/the-dreaming-prince-in-ecstasy"),
                coverImageURL: URL(string: "https://example.com/cover.jpg"),
                sourceCount: 2,
                sourceSignals: ["monthly_pick", "shout_out"],
                sourceEvidence: ["Lamp of Murmuur - The Dreaming Prince in Ecstasy"],
                metalArchives: MonthlyMetalRecommendationMetalArchivesContext(
                    genre: "Raw Black Metal",
                    lyricalThemes: "Night, mysticism",
                    fullLengthAlbumCount: 2,
                    reviewCount: 2,
                    averageReviewScore: 92,
                    yearsActive: 7,
                    fullTimeMemberCount: 2
                ),
                bandcamp: MonthlyMetalRecommendationBandcampContext(
                    hasDigital: true,
                    digitalFormats: ["FLAC", "MP3"],
                    digitalQualityText: "24-bit/96kHz",
                    isHiResAvailable: true,
                    hasCD: true,
                    isCDAvailable: true,
                    cdAvailabilityText: "Compact Disc (CD) + Digital Album"
                ),
                issues: []
            )
        ]
    )
}

private struct SequentialRecommendationStubLLMProvider: LLMProvider {
    private let storage: SequentialRecommendationStubLLMProviderStorage

    init(responses: [String]) {
        self.storage = SequentialRecommendationStubLLMProviderStorage(responses: responses)
    }

    func complete(_ request: LLMRequest) async throws -> String {
        try await storage.nextResponse()
    }

    func requestCount() async -> Int {
        await storage.requestCount
    }
}

private actor SequentialRecommendationStubLLMProviderStorage {
    private var responses: [String]
    private(set) var requestCount = 0

    init(responses: [String]) {
        self.responses = responses
    }

    func nextResponse() throws -> String {
        requestCount += 1

        guard !responses.isEmpty else {
            throw MonthlyMetalError.invalidOperation("No stub LLM responses remain.")
        }

        return responses.removeFirst()
    }
}
