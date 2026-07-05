import Foundation
import LocalLLMKit

struct LocalLLMSourceCandidateExtractor: Sendable {
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

    func extract(from sourceItem: MonthlyMetalSourceItem) async -> MonthlyMetalSourceExtractionResult {
        do {
            let firstResponse = try await provider.complete(LLMRequest(
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt(for: sourceItem),
                temperature: temperature,
                maxTokens: maxTokens
            ))

            switch Self.validateCandidates(from: firstResponse) {
            case .success(let candidates):
                return result(
                    for: sourceItem,
                    candidates: candidates,
                    rawResponse: firstResponse,
                    errorMessage: nil
                )

            case .failure(let firstFailure):
                let repairResponse = try await provider.complete(LLMRequest(
                    model: model,
                    systemPrompt: repairSystemPrompt,
                    userPrompt: Self.repairPrompt(
                        invalidResponse: firstResponse,
                        validationFailure: firstFailure
                    ),
                    temperature: 0,
                    maxTokens: maxTokens
                ))

                switch Self.validateCandidates(from: repairResponse) {
                case .success(let candidates):
                    return result(
                        for: sourceItem,
                        candidates: candidates,
                        rawResponse: Self.combinedRawResponse(
                            first: firstResponse,
                            repair: repairResponse
                        ),
                        errorMessage: nil
                    )

                case .failure(let repairFailure):
                    return result(
                        for: sourceItem,
                        candidates: [],
                        rawResponse: Self.combinedRawResponse(
                            first: firstResponse,
                            repair: repairResponse
                        ),
                        errorMessage: """
                        LLM extraction JSON validation failed after repair.
                        First attempt: \(firstFailure.description)
                        Repair attempt: \(repairFailure.description)
                        """
                    )
                }
            }
        } catch {
            return result(
                for: sourceItem,
                candidates: [],
                rawResponse: nil,
                errorMessage: String(describing: error)
            )
        }
    }

    private func result(
        for sourceItem: MonthlyMetalSourceItem,
        candidates: [MonthlyMetalExtractedSourceCandidate],
        rawResponse: String?,
        errorMessage: String?
    ) -> MonthlyMetalSourceExtractionResult {
        MonthlyMetalSourceExtractionResult(
            sourceName: sourceItem.sourceName,
            sourceKind: sourceItem.sourceKind,
            sourceURL: sourceItem.sourceURL,
            itemURL: sourceItem.itemURL,
            title: sourceItem.title,
            publishedAt: sourceItem.publishedAt,
            candidates: candidates,
            rawResponse: rawResponse,
            errorMessage: errorMessage
        )
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
    }

    private func userPrompt(for sourceItem: MonthlyMetalSourceItem) -> String {
        """
        /no_think

        Source title: \(sourceItem.title ?? "unknown")
        Source name: \(sourceItem.sourceName)
        Source kind: \(sourceItem.sourceKind)
        Source URL: \(sourceItem.sourceURL?.absoluteString ?? "unknown")
        Item URL: \(sourceItem.itemURL?.absoluteString ?? "unknown")
        Published at: \(sourceItem.publishedAt.map { MonthlyMetalDateFormatter.shared.format($0) } ?? "unknown")

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
        \(sourceItem.text)
        """
    }

    private var repairSystemPrompt: String {
        """
        You repair JSON only.

        Return only valid JSON. Do not use markdown.
        Do not add new albums.
        Do not analyze the original source.
        Only repair the previous model response so it matches the required schema.
        If no candidate can be recovered, return {"candidates":[]}.
        """
    }

    private static func repairPrompt(
        invalidResponse: String,
        validationFailure: CandidateValidationFailure
    ) -> String {
        """
        The previous response failed Swift JSON/schema validation.

        Validation issues:
        \(validationFailure.issues.map { "- \($0)" }.joined(separator: "\n"))

        Required shape:
        {
          "candidates": [
            {
              "bandName": "Band",
              "albumTitle": "Album",
              "sourceSignal": "reviewed_album",
              "labelName": null,
              "releaseDateText": null,
              "evidence": "Short evidence from the previous response",
              "confidence": 0.9
            }
          ]
        }

        Allowed sourceSignal values:
        reviewed_album, monthly_pick, shout_out, instagram_arrival, mentioned_album, uncertain

        Invalid response to repair:
        \(invalidResponse)
        """
    }

    private static func combinedRawResponse(first: String, repair: String) -> String {
        """
        --- initial response ---
        \(first)

        --- repair response ---
        \(repair)
        """
    }

    private static let allowedSignals: Set<String> = [
        "reviewed_album",
        "monthly_pick",
        "shout_out",
        "instagram_arrival",
        "mentioned_album",
        "uncertain"
    ]

    private static func validateCandidates(
        from response: String
    ) -> Result<[MonthlyMetalExtractedSourceCandidate], CandidateValidationFailure> {
        let payload = jsonPayload(from: response)
        let data = Data(payload.utf8)
        let envelope: LLMAlbumCandidateEnvelope

        do {
            envelope = try JSONDecoder().decode(LLMAlbumCandidateEnvelope.self, from: data)
        } catch {
            return .failure(CandidateValidationFailure(
                payload: payload,
                issues: [
                    "Response must be valid JSON object with top-level candidates array. Decode error: \(error)"
                ]
            ))
        }

        var issues: [String] = []
        var seen = Set<MonthlyMetalReleaseIdentity>()
        var candidates: [MonthlyMetalExtractedSourceCandidate] = []

        for (index, draft) in envelope.candidates.enumerated() {
            let prefix = "candidates[\(index)]"

            guard let bandName = nonEmpty(draft.bandName) else {
                issues.append("\(prefix).bandName must be a non-empty string")
                continue
            }

            guard let albumTitle = nonEmpty(draft.albumTitle) else {
                issues.append("\(prefix).albumTitle must be a non-empty string")
                continue
            }

            guard let sourceSignal = nonEmpty(draft.sourceSignal),
                  allowedSignals.contains(sourceSignal)
            else {
                issues.append(
                    "\(prefix).sourceSignal must be one of: \(allowedSignals.sorted().joined(separator: ", "))"
                )
                continue
            }

            guard let evidence = nonEmpty(draft.evidence) else {
                issues.append("\(prefix).evidence must be a non-empty string")
                continue
            }

            guard let confidence = draft.confidence,
                  confidence >= 0,
                  confidence <= 1
            else {
                issues.append("\(prefix).confidence must be a number between 0 and 1")
                continue
            }

            let identity = MonthlyMetalReleaseIdentity(
                bandName: bandName,
                albumTitle: albumTitle
            )

            guard seen.insert(identity).inserted else {
                continue
            }

            candidates.append(MonthlyMetalExtractedSourceCandidate(
                bandName: bandName,
                albumTitle: albumTitle,
                sourceSignal: sourceSignal,
                labelName: nonEmpty(draft.labelName),
                releaseDateText: nonEmpty(draft.releaseDateText),
                evidence: evidence,
                confidence: confidence
            ))
        }

        if !issues.isEmpty {
            return .failure(CandidateValidationFailure(payload: payload, issues: issues))
        }

        return .success(candidates)
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

private struct CandidateValidationFailure: Error, CustomStringConvertible {
    let payload: String
    let issues: [String]

    var description: String {
        issues.joined(separator: "; ")
    }
}
