import Foundation
import Testing
@testable import HarnessCore

@Test func localLLMEditorialExtractorRepairsInvalidCandidateJSON() async throws {
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
    let extractor = LocalLLMEditorialCandidateExtractor(
        provider: provider,
        model: "stub-model"
    )

    let result = await extractor.extract(from: editorialDocument())

    #expect(result.errorMessage == nil)
    #expect(result.candidates.count == 1)
    #expect(result.candidates.first?.bandName == "Lamp of Murmuur")
    #expect(result.candidates.first?.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(result.rawResponse?.contains("--- initial response ---") == true)
    #expect(result.rawResponse?.contains("--- repair response ---") == true)
    #expect(await provider.requestCount() == 2)
}

@Test func localLLMEditorialExtractorStoresErrorWhenRepairFailsValidation() async throws {
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
    let extractor = LocalLLMEditorialCandidateExtractor(
        provider: provider,
        model: "stub-model"
    )

    let result = await extractor.extract(from: editorialDocument())

    #expect(result.candidates.isEmpty)
    #expect(result.errorMessage?.contains("validation failed after repair") == true)
    #expect(result.rawResponse?.contains("--- initial response ---") == true)
    #expect(result.rawResponse?.contains("--- repair response ---") == true)
    #expect(await provider.requestCount() == 2)
}

private func editorialDocument() -> MonthlyMetalEditorialSourceDocument {
    MonthlyMetalEditorialSourceDocument(
        sourceName: "Example editorial source",
        sourceKind: "ranked_list",
        sourceURL: URL(string: "https://example.com/editorial"),
        itemURL: URL(string: "https://example.com/editorial/post"),
        title: "Example source document",
        publishedAt: nil,
        text: "Lamp of Murmuur - The Dreaming Prince in Ecstasy"
    )
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
            throw HarnessError.invalidAgentAction("No stub LLM responses remain.")
        }

        return responses.removeFirst()
    }
}
