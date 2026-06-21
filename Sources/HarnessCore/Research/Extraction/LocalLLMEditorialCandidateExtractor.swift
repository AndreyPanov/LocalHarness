import Foundation

struct LocalLLMEditorialCandidateExtractor: Sendable {
    private let provider: any LLMProvider
    private let model: String
    private let temperature: Double
    private let maxTokens: Int

    init(
        provider: any LLMProvider,
        model: String,
        temperature: Double = 0,
        maxTokens: Int = 8192
    ) {
        self.provider = provider
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }

    func extract(from document: MonthlyMetalEditorialSourceDocument) async -> MonthlyMetalEditorialExtractionResult {
        do {
            let response = try await provider.complete(LLMRequest(
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt(for: document),
                temperature: temperature,
                maxTokens: maxTokens
            ))
            let candidates = try Self.decodeCandidates(
                from: response,
                defaultSignal: defaultSignal(for: document)
            )

            return MonthlyMetalEditorialExtractionResult(
                sourceName: document.sourceName,
                sourceKind: document.sourceKind,
                sourceURL: document.sourceURL,
                itemURL: document.itemURL,
                title: document.title,
                publishedAt: document.publishedAt,
                candidates: candidates,
                rawResponse: response,
                errorMessage: nil
            )
        } catch {
            return MonthlyMetalEditorialExtractionResult(
                sourceName: document.sourceName,
                sourceKind: document.sourceKind,
                sourceURL: document.sourceURL,
                itemURL: document.itemURL,
                title: document.title,
                publishedAt: document.publishedAt,
                candidates: [],
                rawResponse: nil,
                errorMessage: String(describing: error)
            )
        }
    }

    private var systemPrompt: String {
        """
        You extract heavy metal album candidates from source descriptions.

        Return only valid JSON. Do not use markdown.
        Return the JSON immediately. Do not explain your reasoning.
        Do not include analysis, notes, code fences, or prose.
        Do not invent facts. Use null for unknown fields.
        If an album is self-titled, return the band's name as albumTitle.
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
    }

    private func userPrompt(for document: MonthlyMetalEditorialSourceDocument) -> String {
        """
        /no_think

        Source title: \(document.title ?? "unknown")
        Source name: \(document.sourceName)
        Source kind: \(document.sourceKind)
        Source URL: \(document.sourceURL?.absoluteString ?? "unknown")
        Item URL: \(document.itemURL?.absoluteString ?? "unknown")
        Published at: \(document.publishedAt.map { MonthlyMetalDateFormatter.shared.format($0) } ?? "unknown")

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

        Instagram arrival posts usually list records as album arrivals, stock updates, or format notes.
        For Instagram arrival posts, use sourceSignal instagram_arrival unless the post is clearly only a general mention.
        Extract every album or release listed in the post caption.

        Full description:
        \(document.text)
        """
    }

    private func defaultSignal(for document: MonthlyMetalEditorialSourceDocument) -> String {
        if document.sourceKind.contains("instagram") {
            return "instagram_arrival"
        }

        if document.sourceKind.contains("monthly") {
            return "monthly_pick"
        }

        if document.sourceKind.contains("review") {
            return "reviewed_album"
        }

        return "mentioned_album"
    }

    private static func decodeCandidates(
        from response: String,
        defaultSignal: String
    ) throws -> [MonthlyMetalExtractedEditorialCandidate] {
        let json = jsonPayload(from: response)
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let drafts: [LLMAlbumCandidateDraft]

        if let envelope = try? decoder.decode(LLMAlbumCandidateEnvelope.self, from: data) {
            drafts = envelope.candidates
        } else if let candidateDrafts = try? decoder.decode([LLMAlbumCandidateDraft].self, from: data) {
            drafts = candidateDrafts
        } else {
            drafts = [try decoder.decode(LLMAlbumCandidateDraft.self, from: data)]
        }

        var seen = Set<MonthlyMetalReleaseIdentity>()

        return drafts.compactMap { draft in
            guard let bandName = nonEmpty(draft.bandName),
                  let albumTitle = nonEmpty(draft.albumTitle)
            else {
                return nil
            }

            let identity = MonthlyMetalReleaseIdentity(
                bandName: bandName,
                albumTitle: albumTitle
            )

            guard seen.insert(identity).inserted else {
                return nil
            }

            return MonthlyMetalExtractedEditorialCandidate(
                bandName: bandName,
                albumTitle: albumTitle,
                sourceSignal: nonEmpty(draft.sourceSignal) ?? defaultSignal,
                labelName: nonEmpty(draft.labelName),
                releaseDateText: nonEmpty(draft.releaseDateText),
                evidence: nonEmpty(draft.evidence) ?? "\(bandName) - \(albumTitle)",
                confidence: clampedConfidence(draft.confidence)
            )
        }
    }

    private static func jsonPayload(from response: String) -> String {
        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^```(?:json)?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)

        guard let start = cleaned.firstIndex(where: { $0 == "{" || $0 == "[" }) else {
            return cleaned
        }

        let openingCharacter = cleaned[start]
        let closingCharacter: Character = openingCharacter == "[" ? "]" : "}"

        guard let end = cleaned.lastIndex(of: closingCharacter) else {
            return cleaned
        }

        return String(cleaned[start...end])
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func clampedConfidence(_ confidence: Double?) -> Double {
        guard let confidence else {
            return 0.5
        }

        return min(1, max(0, confidence))
    }
}

private struct LLMAlbumCandidateEnvelope: Decodable {
    let candidates: [LLMAlbumCandidateDraft]
}

private struct LLMAlbumCandidateDraft: Decodable {
    let bandName: String?
    let albumTitle: String?
    let sourceSignal: String?
    let labelName: String?
    let releaseDateText: String?
    let evidence: String?
    let confidence: Double?
}
