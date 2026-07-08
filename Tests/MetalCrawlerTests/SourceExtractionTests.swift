import Foundation
import LocalLLMKit
import Testing
@testable import MetalCrawlerCore

@Test func localLLMSourceExtractorRepairsInvalidCandidateJSON() async throws {
    let provider = SequentialStubLLMProvider(responses: [
        """
        {
          "candidates": [
            {
              "bandName": "Lamp of Murmuur",
              "albumTitle": "The Dreaming Prince in Ecstasy",
              "sourceSignal": "mentioned_album",
              "confidence": 0.8
            }
          ]
        }
        """,
        """
        {
          "candidates": [
            {
              "bandName": "Lamp of Murmuur",
              "albumTitle": "The Dreaming Prince in Ecstasy",
              "sourceSignal": "mentioned_album",
              "labelName": null,
              "releaseDateText": null,
              "evidence": "Lamp of Murmuur - The Dreaming Prince in Ecstasy",
              "confidence": 0.8
            }
          ]
        }
        """
    ])
    let extractor = LocalLLMSourceCandidateExtractor(
        provider: provider,
        model: "stub-model"
    )

    let result = await extractor.extract(from: sourceItem())

    #expect(result.errorMessage == nil)
    #expect(result.candidates.count == 1)
    #expect(result.candidates.first?.bandName == "Lamp of Murmuur")
    #expect(result.candidates.first?.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(result.rawResponse?.contains("--- initial response ---") == true)
    #expect(result.rawResponse?.contains("--- repair response ---") == true)
    #expect(await provider.requestCount() == 2)
}

@Test func localLLMSourceExtractorStoresErrorWhenRepairFailsValidation() async throws {
    let provider = SequentialStubLLMProvider(responses: [
        """
        {
          "candidates": [
            {
              "bandName": "Lamp of Murmuur",
              "albumTitle": "The Dreaming Prince in Ecstasy",
              "sourceSignal": "not_allowed",
              "evidence": "Lamp of Murmuur - The Dreaming Prince in Ecstasy",
              "confidence": 0.8
            }
          ]
        }
        """,
        """
        {
          "candidates": [
            {
              "bandName": "",
              "albumTitle": "",
              "sourceSignal": "not_allowed",
              "evidence": "",
              "confidence": 4.2
            }
          ]
        }
        """
    ])
    let extractor = LocalLLMSourceCandidateExtractor(
        provider: provider,
        model: "stub-model"
    )

    let result = await extractor.extract(from: sourceItem())

    #expect(result.candidates.isEmpty)
    #expect(result.errorMessage?.contains("validation failed after repair") == true)
    #expect(result.rawResponse?.contains("--- initial response ---") == true)
    #expect(result.rawResponse?.contains("--- repair response ---") == true)
    #expect(await provider.requestCount() == 2)
}

@Test func localLLMSourceExtractorTellsModelToIgnoreSongLists() async throws {
    let provider = CapturingStubLLMProvider(response: #"{"candidates":[]}"#)
    let extractor = LocalLLMSourceCandidateExtractor(
        provider: provider,
        model: "stub-model"
    )
    let sourceItem = MonthlyMetalSourceItem(
        sourceName: "InfidelAmsterdam Instagram",
        sourceKind: "instagram_post",
        sourceURL: URL(string: "https://www.instagram.com/infidelamsterdam/"),
        itemURL: URL(string: "https://www.instagram.com/p/DZS1hwysV1q/"),
        title: "Instagram post DZS1hwysV1q",
        publishedAt: nil,
        text: """
        5 albums with a green colored cover!

        Songs:
        Concrete icon: Rats in the matrix
        Chasmdweller: Oracle of innumerable truths
        Abnormity: Vomit carnage
        """
    )

    let result = await extractor.extract(from: sourceItem)
    let request = try #require(await provider.lastRequest())

    #expect(result.errorMessage == nil)
    #expect(result.candidates.isEmpty)
    #expect(request.systemPrompt.contains("songs or tracks"))
    #expect(request.systemPrompt.contains("return no candidates from that song list"))
    #expect(request.userPrompt.contains("Ignore sections headed \"Songs\""))
    #expect(request.userPrompt.contains("Band: Song title"))
}

private func sourceItem() -> MonthlyMetalSourceItem {
    MonthlyMetalSourceItem(
        sourceName: "Example source",
        sourceKind: "youtube_monthly",
        sourceURL: URL(string: "https://example.com/source"),
        itemURL: URL(string: "https://example.com/source/post"),
        title: "Example source item",
        publishedAt: nil,
        text: "Lamp of Murmuur - The Dreaming Prince in Ecstasy"
    )
}

private struct CapturingStubLLMProvider: LLMProvider {
    private let storage: CapturingStubLLMProviderStorage

    init(response: String) {
        self.storage = CapturingStubLLMProviderStorage(response: response)
    }

    func complete(_ request: LLMRequest) async throws -> String {
        await storage.record(request)
    }

    func lastRequest() async -> LLMRequest? {
        await storage.lastRequest
    }
}

private actor CapturingStubLLMProviderStorage {
    private let response: String
    private(set) var lastRequest: LLMRequest?

    init(response: String) {
        self.response = response
    }

    func record(_ request: LLMRequest) -> String {
        self.lastRequest = request
        return response
    }
}

private struct SequentialStubLLMProvider: LLMProvider {
    private let storage: SequentialStubLLMProviderStorage

    init(responses: [String]) {
        self.storage = SequentialStubLLMProviderStorage(responses: responses)
    }

    func complete(_ request: LLMRequest) async throws -> String {
        try await storage.nextResponse()
    }

    func requestCount() async -> Int {
        await storage.requestCount
    }
}

private actor SequentialStubLLMProviderStorage {
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
