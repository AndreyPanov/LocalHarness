import Foundation
import Testing
@testable import HarnessCore

private let liveLLMTestsEnabled = ProcessInfo.processInfo.environment["RUN_LIVE_LLM_TESTS"] == "1"

@Test/*(.enabled(if: liveLLMTestsEnabled))*/
func liveLLMServerRespondsToSimplePrompt() async throws {
    let config = try await LiveLLMTestConfig.load()
    let provider = OpenAICompatibleLLMProvider(baseURL: config.baseURL)

    print("[LiveLLM] baseURL: \(config.baseURL.absoluteString)")
    print("[LiveLLM] model: \(config.model)")
    print("[LiveLLM] temperature: \(config.temperature)")

    let response = try await provider.complete(LLMRequest(
        model: config.model,
        systemPrompt: "You are a test responder. Reply with JSON only.",
        userPrompt: #"Return exactly: {"ok": true}"#,
        temperature: 0
    ))

    print("[LiveLLM] simple response:")
    print(response)
    try LiveLLMOutputWriter.writeText(
        response,
        fileName: "simple-response.txt"
    )

    #expect(response.contains("ok"))
}

@Test/*(.enabled(if: liveLLMTestsEnabled))*/
func liveLLMExtractsCandidatesFromBangerTVMonthlyVideo() async throws {
    let config = try await LiveLLMTestConfig.load()
    let videoURL = URL(string: "https://www.youtube.com/watch?v=Punc3i5Su30")!

    print("[LiveLLM] fetching monthly video: \(videoURL.absoluteString)")

    let description = try await fetchYouTubeDescription(videoURL)
    print("[LiveLLM] monthly description length: \(description.count)")
    print("[LiveLLM] monthly description preview:")
    print(String(description.prefix(1200)))
    try LiveLLMOutputWriter.writeText(
        description,
        fileName: "bangertv-monthly-description.txt"
    )
    let candidates = try await extractCandidates(
        description: description,
        sourceTitle: "BangerTV Metal Monthly June 2026",
        sourceKind: "youtube_monthly",
        outputName: "bangertv-monthly",
        config: config
    )

    print("[LiveLLM] monthly extracted candidates count: \(candidates.count)")
    for candidate in candidates {
        print("[LiveLLM] candidate: \(candidate.bandName) - \(candidate.albumTitle)")
        print("[LiveLLM] signal: \(candidate.sourceSignal ?? "nil")")
    }

    #expect(candidates.count >= 3)
    #expect(candidates.contains { normalize($0.bandName).contains("astriferous") })
    #expect(candidates.allSatisfy { !$0.bandName.isEmpty })
    #expect(candidates.allSatisfy { !$0.albumTitle.isEmpty })
    #expect(candidates.allSatisfy { ($0.confidence ?? 0.5) >= 0 && ($0.confidence ?? 0.5) <= 1 })
}

@Test/*(.enabled(if: liveLLMTestsEnabled))*/
func liveLLMExtractsReviewedAlbumAndShoutoutsFromBangerTVReview() async throws {
    let config = try await LiveLLMTestConfig.load()
    let videoURL = URL(string: "https://www.youtube.com/watch?v=DV-Z4kzZMfM")!
    let description = try await fetchYouTubeDescription(videoURL)
    try LiveLLMOutputWriter.writeText(
        description,
        fileName: "bangertv-review-description.txt"
    )
    let candidates = try await extractCandidates(
        description: description,
        sourceTitle: "BangerTV Khemmis review",
        sourceKind: "youtube_album_review",
        outputName: "bangertv-review",
        config: config
    )

    #expect(candidates.contains { normalize($0.bandName).contains("khemmis") })
    #expect(candidates.contains { $0.sourceSignal == "reviewed_album" })
    #expect(candidates.contains { $0.sourceSignal == "shout_out" })
}

@Test/*(.enabled(if: liveLLMTestsEnabled))*/
func liveLLMExtractsCandidatesFromBangerTVJuneSourceDocuments() async throws {
    let config = try await LiveLLMTestConfig.load()
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2026-06-01"))
    let temp = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-harness-live-llm-tests", isDirectory: true)
    let context = ResearchContext(
        month: month,
        runID: RunID("live-llm-bangertv"),
        crawlClient: CachedCrawlClient(
            wrapped: URLSessionCrawlClient(),
            cacheDirectory: temp.appendingPathComponent("crawl-cache", isDirectory: true)
        ),
        llmFallback: FailingLLMFallback(),
        runsDirectory: temp,
        knowledgeDirectory: temp
    )
    let descriptor = EditorialSourceDescriptor(
        name: "BangerTV",
        kind: "youtube_channel",
        sourceURL: URL(string: "https://www.youtube.com/@BangerTV")!,
        channelID: "UCeUMZ4t3ezEJFhXHJg9rshQ"
    )
    let documents = try await BangerTVEditorialDocumentSource().documents(
        for: month,
        descriptor: descriptor,
        context: context
    )
    var candidates: [LLMAlbumCandidate] = []

    print("[LiveLLM] BangerTV documents count: \(documents.count)")

    for document in documents {
        candidates.append(contentsOf: try await extractCandidates(
            description: document.text,
            sourceTitle: document.title ?? "BangerTV document",
            sourceKind: document.sourceKind,
            outputName: LiveLLMOutputWriter.safeFileName(document.title ?? document.sourceKind),
            config: config
        ))
        print("[LiveLLM] document: \(document.title ?? "untitled")")
        print("[LiveLLM] kind: \(document.sourceKind)")
        print("[LiveLLM] text chars: \(document.text.count)")
    }

    #expect(documents.count >= 2)
    #expect(documents.contains { $0.sourceKind == "youtube_monthly" })
    #expect(documents.contains { $0.sourceKind == "youtube_album_review" })
    #expect(candidates.count >= 5)
    #expect(candidates.allSatisfy { !$0.bandName.isEmpty && !$0.albumTitle.isEmpty })
}

private struct LiveLLMTestConfig {
    let baseURL: URL
    let model: String
    let temperature: Double

    static func load() async throws -> LiveLLMTestConfig {
        let env = ProcessInfo.processInfo.environment
        let baseURL = URL(string: env["LOCAL_HARNESS_LLM_BASE_URL"] ?? "http://127.0.0.1:8081/v1")!
        let configuredModel = env["LOCAL_HARNESS_LLM_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model: String

        if let configuredModel,
           !configuredModel.isEmpty,
           configuredModel != "your-real-model-id",
           configuredModel != "your-exact-model-id"
        {
            model = configuredModel
        } else {
            model = try await discoverFirstModelID(baseURL: baseURL)
        }

        return LiveLLMTestConfig(
            baseURL: baseURL,
            model: model,
            temperature: Double(env["LOCAL_HARNESS_LLM_TEMPERATURE"] ?? "0") ?? 0
        )
    }

    private static func discoverFirstModelID(baseURL: URL) async throws -> String {
        let modelsURL = baseURL.appendingPathComponent("models")
        let (data, response) = try await URLSession.shared.data(from: modelsURL)
        let body = String(data: data, encoding: .utf8) ?? ""

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw HarnessError.llmRequestFailed(statusCode: nil, body: body)
        }

        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)

        guard let modelID = decoded.data.first?.id,
              !modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw HarnessError.invalidAgentAction("No models returned from \(modelsURL.absoluteString).")
        }

        print("[LiveLLM] discovered model from /v1/models: \(modelID)")
        try LiveLLMOutputWriter.writeText(
            body,
            fileName: "models-response.json"
        )
        return modelID
    }
}

private struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]
}

private struct OpenAIModel: Decodable {
    let id: String
}

private func fetchYouTubeDescription(_ url: URL) async throws -> String {
    let page = try await URLSessionCrawlClient().fetch(
        CrawlRequest(url: url, source: ResearchSource(rawValue: "youtube_video"))
    )

    return try #require(
        YouTubeVideoDescriptionExtractor().description(from: page.html ?? page.text),
        "Could not extract YouTube description."
    )
}

private func extractCandidates(
    description: String,
    sourceTitle: String,
    sourceKind: String,
    outputName: String,
    config: LiveLLMTestConfig
) async throws -> [LLMAlbumCandidate] {
    let provider = OpenAICompatibleLLMProvider(baseURL: config.baseURL)

    print("[LiveLLM] extracting candidates")
    print("[LiveLLM] sourceTitle: \(sourceTitle)")
    print("[LiveLLM] sourceKind: \(sourceKind)")
    print("[LiveLLM] prompt description chars: \(description.count)")

    let response = try await provider.complete(LLMRequest(
        model: config.model,
        systemPrompt: albumExtractionSystemPrompt,
        userPrompt: """
        Source title: \(sourceTitle)
        Source kind: \(sourceKind)

        Full description:
        \(description)
        """,
        temperature: config.temperature
    ))

    print("[LiveLLM] raw model response:")
    print(response)
    try LiveLLMOutputWriter.writeText(
        response,
        fileName: "\(outputName)-raw-response.txt"
    )

    let json = jsonPayload(from: response)
    print("[LiveLLM] extracted JSON payload:")
    print(json)
    try LiveLLMOutputWriter.writePrettyJSON(
        json,
        fileName: "\(outputName)-candidates.json"
    )
    let envelope = try JSONDecoder().decode(LLMAlbumCandidateEnvelope.self, from: Data(json.utf8))
    print("[LiveLLM] decoded candidates: \(envelope.candidates.count)")

    return envelope.candidates.filter {
        !$0.bandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !$0.albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private let albumExtractionSystemPrompt = """
You extract heavy metal album candidates from source descriptions.

Return only valid JSON. Do not use markdown.
Do not invent facts. Use null for unknown fields.
If an album is self-titled - return band's name as an album title.
Extract reviewed albums, monthly picks, shout-outs, and store arrival mentions.

Return this exact shape:
{
  "candidates": [
    {
      "bandName": "Band",
      "albumTitle": "Album",
      "sourceSignal": "reviewed_album",
      "labelName": null,
      "releaseDateText": null,
      "evidence": "Short evidence from the source",
      "confidence": 0.9
    }
  ]
}

Allowed sourceSignal values:
reviewed_album, monthly_pick, shout_out, instagram_arrival, mentioned_album, uncertain
"""

private struct LLMAlbumCandidateEnvelope: Decodable {
    let candidates: [LLMAlbumCandidate]
}

private struct LLMAlbumCandidate: Decodable {
    let bandName: String
    let albumTitle: String
    let sourceSignal: String?
    let labelName: String?
    let releaseDateText: String?
    let evidence: String?
    let confidence: Double?
}

private enum LiveLLMOutputWriter {
    static func writeText(_ text: String, fileName: String) throws {
        let url = try outputDirectory().appendingPathComponent(fileName, isDirectory: false)
        try text.write(to: url, atomically: true, encoding: .utf8)
        print("[LiveLLM] wrote: \(url.path)")
    }

    static func writePrettyJSON(_ json: String, fileName: String) throws {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object)
        else {
            try writeText(json, fileName: fileName)
            return
        }

        let prettyData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        let prettyJSON = String(data: prettyData, encoding: .utf8) ?? json
        try writeText(prettyJSON, fileName: fileName)
    }

    static func safeFileName(_ value: String) -> String {
        let sanitized = value
            .replacingOccurrences(
                of: #"[^A-Za-z0-9_-]+"#,
                with: "-",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"-+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return sanitized.isEmpty ? "llm-output" : String(sanitized.prefix(80))
    }

    private static func outputDirectory() throws -> URL {
        let directory = packageRoot()
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("live-llm-output", isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
    }

    private static func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private func jsonPayload(from response: String) -> String {
    let cleaned = response
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
        .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)

    guard let start = cleaned.firstIndex(of: "{"),
          let end = cleaned.lastIndex(of: "}")
    else {
        return cleaned
    }

    return String(cleaned[start...end])
}

private func normalize(_ value: String) -> String {
    value
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .lowercased()
}

private struct FailingLLMFallback: LLMExtractionFallback {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate {
        throw HarnessError.invalidAgentAction("LLM fallback should not be used.")
    }

    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft {
        throw HarnessError.invalidAgentAction("LLM fallback should not be used.")
    }
}
