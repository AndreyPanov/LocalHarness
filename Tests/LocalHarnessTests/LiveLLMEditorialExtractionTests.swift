import Foundation
import Testing
@testable import HarnessCore

private let liveLLMTestsEnabled = ProcessInfo.processInfo.environment["RUN_LIVE_LLM_TESTS"] == "1"

@Suite(.serialized)
struct LiveLLMEditorialExtractionTests {
@Test(.enabled(if: liveLLMTestsEnabled))
func serverRespondsToSimplePrompt() async throws {
    let config = try await LiveLLMTestConfig.load()
    let provider = makeLiveLLMProvider(config: config)

    print("[LiveLLM] baseURL: \(config.baseURL.absoluteString)")
    print("[LiveLLM] model: \(config.model)")
    print("[LiveLLM] temperature: \(config.temperature)")
    print("[LiveLLM] maxTokens: \(config.maxTokens)")
    print("[LiveLLM] requestTimeout: \(config.requestTimeout)")

    let response = try await provider.complete(LLMRequest(
        model: config.model,
        systemPrompt: "You are a test responder. Reply with JSON only.",
        userPrompt: #"Return exactly: {"ok": true}"#,
        temperature: 0,
        maxTokens: config.maxTokens
    ))

    print("[LiveLLM] simple response:")
    print(response)
    try LiveLLMOutputWriter.writeText(
        response,
        fileName: "simple-response.txt"
    )

    #expect(response.contains("ok"))
}

@Test(.enabled(if: liveLLMTestsEnabled))
func extractsCandidatesFromBangerTVMonthlyVideo() async throws {
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

@Test(.enabled(if: liveLLMTestsEnabled))
func extractsReviewedAlbumAndShoutoutsFromBangerTVReview() async throws {
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

@Test(.enabled(if: liveLLMTestsEnabled))
func extractsCandidatesFromBangerTVJuneSourceDocuments() async throws {
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

@Test(.enabled(if: liveLLMTestsEnabled))
func extractsCandidatesFromInfidelAmsterdamInstagramPosts() async throws {
    let config = try await LiveLLMTestConfig.load()
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2026-06-01"))
    let temp = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-harness-live-llm-tests", isDirectory: true)
    let context = ResearchContext(
        month: month,
        runID: RunID("live-llm-instagram"),
        crawlClient: CachedCrawlClient(
            wrapped: URLSessionCrawlClient(),
            cacheDirectory: temp.appendingPathComponent("crawl-cache", isDirectory: true)
        ),
        llmFallback: FailingLLMFallback(),
        runsDirectory: temp,
        knowledgeDirectory: temp
    )
    let descriptor = EditorialSourceDescriptor(
        name: "InfidelAmsterdam Instagram",
        kind: "instagram_profile",
        sourceURL: URL(string: "https://www.instagram.com/infidelamsterdam/")!,
        username: "infidelamsterdam"
    )
    let documents = try await InstagramProfileEditorialDocumentSource(maxPages: 4).documents(
        for: month,
        descriptor: descriptor,
        context: context
    )
    let albumLikeDocuments = documents.filter(isLikelyInstagramAlbumPost)
    let limitedDocuments = Array(albumLikeDocuments.prefix(config.instagramDocumentLimit))
    var candidates: [LLMAlbumCandidate] = []

    print("[LiveLLM] Instagram documents count: \(documents.count)")
    print("[LiveLLM] Instagram album-like documents count: \(albumLikeDocuments.count)")
    print("[LiveLLM] Instagram documents sent to LLM: \(limitedDocuments.count)")

    for document in limitedDocuments {
        let outputName = LiveLLMOutputWriter.safeFileName(document.title ?? document.sourceKind)
        try LiveLLMOutputWriter.writeText(
            document.text,
            fileName: "\(outputName)-caption.txt"
        )
        candidates.append(contentsOf: try await extractCandidates(
            description: document.text,
            sourceTitle: document.title ?? "InfidelAmsterdam Instagram post",
            sourceKind: document.sourceKind,
            outputName: outputName,
            config: config
        ))
        print("[LiveLLM] Instagram document: \(document.title ?? "untitled")")
        print("[LiveLLM] itemURL: \(document.itemURL?.absoluteString ?? "unknown")")
        print("[LiveLLM] caption chars: \(document.text.count)")
    }

    print("[LiveLLM] Instagram extracted candidates count: \(candidates.count)")
    for candidate in candidates {
        print("[LiveLLM] Instagram candidate: \(candidate.bandName) - \(candidate.albumTitle)")
        print("[LiveLLM] signal: \(candidate.sourceSignal ?? "nil")")
    }

    #expect(!documents.isEmpty)
    #expect(!albumLikeDocuments.isEmpty)
    #expect(!limitedDocuments.isEmpty)
    #expect(!candidates.isEmpty)
    #expect(candidates.allSatisfy { !$0.bandName.isEmpty && !$0.albumTitle.isEmpty })
}
}

private struct LiveLLMTestConfig {
    let baseURL: URL
    let model: String
    let temperature: Double
    let maxTokens: Int
    let requestTimeout: TimeInterval
    let instagramDocumentLimit: Int

    static func load() async throws -> LiveLLMTestConfig {
        let env = ProcessInfo.processInfo.environment
        let baseURL = URL(string: env["LOCAL_HARNESS_LLM_BASE_URL"] ?? "http://127.0.0.1:8081/v1")!
        let configuredModel = env["LOCAL_HARNESS_LLM_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = if let configuredModel, !configuredModel.isEmpty {
            configuredModel
        } else {
            "mlx-community/Qwen3.6-35B-A3B-4bit-DWQ"
        }

        return LiveLLMTestConfig(
            baseURL: baseURL,
            model: model,
            temperature: Double(env["LOCAL_HARNESS_LLM_TEMPERATURE"] ?? "0") ?? 0,
            maxTokens: Int(env["LOCAL_HARNESS_LLM_MAX_TOKENS"] ?? "8192") ?? 8192,
            requestTimeout: TimeInterval(env["LOCAL_HARNESS_LLM_TIMEOUT"] ?? "300") ?? 300,
            instagramDocumentLimit: Int(env["LOCAL_HARNESS_INSTAGRAM_DOCUMENT_LIMIT"] ?? "3") ?? 3
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

private func makeLiveLLMProvider(config: LiveLLMTestConfig) -> OpenAICompatibleLLMProvider {
    let sessionConfiguration = URLSessionConfiguration.default
    sessionConfiguration.timeoutIntervalForRequest = config.requestTimeout
    sessionConfiguration.timeoutIntervalForResource = config.requestTimeout

    return OpenAICompatibleLLMProvider(
        baseURL: config.baseURL,
        session: URLSession(configuration: sessionConfiguration)
    )
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
    let provider = makeLiveLLMProvider(config: config)

    print("[LiveLLM] extracting candidates")
    print("[LiveLLM] sourceTitle: \(sourceTitle)")
    print("[LiveLLM] sourceKind: \(sourceKind)")
    print("[LiveLLM] prompt description chars: \(description.count)")

    let response = try await provider.complete(LLMRequest(
        model: config.model,
        systemPrompt: albumExtractionSystemPrompt,
        userPrompt: """
        /no_think

        Source title: \(sourceTitle)
        Source kind: \(sourceKind)

        BangerTV monthly descriptions usually repeat this block:
        band name
        album title
        label name
        release date
        link

        For example:
        Astriferous
        Atavistic Unraveling
        Me Saco un Ojo/Pulverised
        June 26th, 2026

        means bandName is Astriferous, albumTitle is Atavistic Unraveling, labelName is Me Saco un Ojo/Pulverised.
        Do not create album candidates from label names or URLs.

        BangerTV album review descriptions can include one reviewed album plus a Shout Outs section.
        For source kind youtube_album_review:
        - Extract the reviewed album with sourceSignal reviewed_album.
        - Extract every album in a Shout Outs section with sourceSignal shout_out.
        - Shout-out lines can look like "Band - Album - release date - label".
        - Do not stop after the reviewed album if shout-outs are present.

        Instagram arrival posts usually list records as album arrivals, stock updates, or format notes.
        For Instagram arrival posts, use sourceSignal instagram_arrival unless the post is clearly only a general mention.
        Extract every album or release listed in the post caption.

        Full description:
        \(description)
        """,
        temperature: config.temperature,
        maxTokens: config.maxTokens
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
    let candidates = try decodeCandidates(from: json)
    print("[LiveLLM] decoded candidates: \(candidates.count)")

    return candidates.filter {
        !$0.bandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !$0.albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private func isLikelyInstagramAlbumPost(_ document: MonthlyMetalEditorialSourceDocument) -> Bool {
    let text = document.text
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .lowercased()

    let albumSignals = [
        "new arrival",
        "new arrivals",
        "vinyl",
        " lp",
        " cd",
        "cassette",
        "tape",
        "full length",
        "full-length",
        "album",
        "demo",
        "ep",
        "black metal",
        "death metal",
        "doom metal",
        "heavy metal",
        "thrash metal"
    ]

    return albumSignals.contains { text.contains($0) }
}

private let albumExtractionSystemPrompt = """
You extract heavy metal album candidates from source descriptions.

Return only valid JSON. Do not use markdown.
Return the JSON immediately. Do not explain your reasoning.
Do not include analysis, notes, code fences, or prose.
Do not invent facts. Use null for unknown fields.
If an album is self-titled - return band's name as an album title.
Extract reviewed albums, monthly picks, shout-outs, and store arrival mentions.
When a section is named "Shout Outs", "SHOUTOUTS", or similar, every album line in that section is an album candidate.

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

    private enum CodingKeys: CodingKey {
        case bandName
        case albumTitle
        case sourceSignal
        case labelName
        case releaseDateText
        case evidence
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.bandName = try container.decodeIfPresent(String.self, forKey: .bandName) ?? ""
        self.albumTitle = try container.decodeIfPresent(String.self, forKey: .albumTitle) ?? ""
        self.sourceSignal = try container.decodeIfPresent(String.self, forKey: .sourceSignal)
        self.labelName = try container.decodeIfPresent(String.self, forKey: .labelName)
        self.releaseDateText = try container.decodeIfPresent(String.self, forKey: .releaseDateText)
        self.evidence = try container.decodeIfPresent(String.self, forKey: .evidence)
        self.confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
    }
}

private func decodeCandidates(from json: String) throws -> [LLMAlbumCandidate] {
    let data = Data(json.utf8)
    let decoder = JSONDecoder()

    if let envelope = try? decoder.decode(LLMAlbumCandidateEnvelope.self, from: data) {
        return envelope.candidates
    }

    if let candidates = try? decoder.decode([LLMAlbumCandidate].self, from: data) {
        return candidates
    }

    return [try decoder.decode(LLMAlbumCandidate.self, from: data)]
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

    guard let start = cleaned.firstIndex(where: { $0 == "{" || $0 == "[" }) else {
        return cleaned
    }

    let openingCharacter = cleaned[start]
    let closingCharacter: Character = openingCharacter == "[" ? "]" : "}"

    guard let end = cleaned.lastIndex(of: closingCharacter)
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
