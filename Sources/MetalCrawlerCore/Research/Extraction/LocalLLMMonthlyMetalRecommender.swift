import Foundation
import LocalLLMKit

struct LocalLLMMonthlyMetalRecommender: Sendable {
    static let promptVersion = "monthly-metal-recommendations-v1"

    private let provider: any LLMProvider
    private let model: String
    private let temperature: Double
    private let maxTokens: Int
    private let limit: Int

    init(
        provider: any LLMProvider,
        model: String,
        temperature: Double = 0.2,
        maxTokens: Int = 8192,
        limit: Int = 30
    ) {
        self.provider = provider
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.limit = max(1, limit)
    }

    func recommend(
        month: String,
        context: MonthlyMetalRecommendationContextArtifact
    ) async -> MonthlyMetalRecommendationArtifact {
        do {
            let firstResponse = try await provider.complete(LLMRequest(
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: try userPrompt(month: month, context: context),
                temperature: temperature,
                maxTokens: maxTokens
            ))

            switch Self.validateRecommendations(
                from: firstResponse,
                context: context,
                limit: limit
            ) {
            case .success(let recommendations):
                return artifact(
                    month: month,
                    recommendations: recommendations,
                    rawResponse: firstResponse,
                    errorMessage: nil
                )

            case .failure(let firstFailure):
                let repairResponse = try await provider.complete(LLMRequest(
                    model: model,
                    systemPrompt: repairSystemPrompt,
                    userPrompt: Self.repairPrompt(
                        invalidResponse: firstResponse,
                        validationFailure: firstFailure,
                        context: context,
                        limit: limit
                    ),
                    temperature: 0,
                    maxTokens: maxTokens
                ))

                switch Self.validateRecommendations(
                    from: repairResponse,
                    context: context,
                    limit: limit
                ) {
                case .success(let recommendations):
                    return artifact(
                        month: month,
                        recommendations: recommendations,
                        rawResponse: Self.combinedRawResponse(
                            first: firstResponse,
                            repair: repairResponse
                        ),
                        errorMessage: nil
                    )

                case .failure(let repairFailure):
                    return artifact(
                        month: month,
                        recommendations: [],
                        rawResponse: Self.combinedRawResponse(
                            first: firstResponse,
                            repair: repairResponse
                        ),
                        errorMessage: """
                        LLM recommendation JSON validation failed after repair.
                        First attempt: \(firstFailure.description)
                        Repair attempt: \(repairFailure.description)
                        """
                    )
                }
            }
        } catch {
            return artifact(
                month: month,
                recommendations: [],
                rawResponse: nil,
                errorMessage: String(describing: error)
            )
        }
    }

    private func artifact(
        month: String,
        recommendations: [MonthlyMetalRecommendation],
        rawResponse: String?,
        errorMessage: String?
    ) -> MonthlyMetalRecommendationArtifact {
        MonthlyMetalRecommendationArtifact(
            month: month,
            model: model,
            promptVersion: Self.promptVersion,
            recommendations: recommendations.sorted { $0.rank < $1.rank },
            rawResponse: rawResponse,
            errorMessage: errorMessage
        )
    }

    private var systemPrompt: String {
        """
        You recommend heavy metal albums from already collected facts.

        Use only the provided candidate facts.
        Do not invent albums, links, artwork, labels, genres, review scores, or availability.
        Rank albums by likely fit for a metal listener who wants distinctive, high-signal monthly discoveries.
        Prefer strong genre identity, credible source mentions, interesting discography context, good review signals, and useful Bandcamp/CD availability.
        Missing data is not a reason to invent. Call it unknown or include a caution reason.
        Return only valid JSON. Do not use markdown.
        Return the JSON immediately. Do not include prose, notes, analysis, or code fences.
        """
    }

    private func userPrompt(
        month: String,
        context: MonthlyMetalRecommendationContextArtifact
    ) throws -> String {
        """
        /no_think

        Month: \(month)
        Recommendation limit: \(limit)

        Initial taste profile:
        - Favor albums and EPs with clear metal identity and memorable genre character.
        - Favor Bandcamp availability, especially FLAC/hi-res digital and available CD copies.
        - Favor candidates backed by multiple source signals or concrete source evidence.
        - Favor bands with enough context to judge, but do not punish new bands too harshly.
        - Deprioritize weakly evidenced candidates, non-album items, uncertain matches, and releases with no useful enrichment.

        Candidate facts:
        \(try Self.prettyJSON(context))

        Return this exact JSON shape:
        {
          "recommendations": [
            {
              "rank": 1,
              "bandName": "Band exactly as provided",
              "albumTitle": "Album exactly as provided",
              "decision": "must_check",
              "confidence": 0.9,
              "fitReasons": [
                "Reason based only on provided facts"
              ],
              "cautionReasons": [],
              "purchaseNotes": "Bandcamp has FLAC and available CD",
              "evidence": [
                "Concrete provided fact or source evidence"
              ]
            }
          ]
        }

        Allowed decision values:
        must_check, likely_interesting, maybe, skip

        Rules:
        - Recommend at most \(limit) albums.
        - Use only candidates from Candidate facts.
        - Preserve bandName and albumTitle exactly.
        - rank must start at 1 and be unique.
        - confidence must be between 0 and 1.
        - fitReasons and evidence must contain at least one item.
        - cautionReasons can be empty.
        - purchaseNotes can be null.
        """
    }

    private var repairSystemPrompt: String {
        """
        You repair recommendation JSON only.

        Return only valid JSON. Do not use markdown.
        Do not add new albums.
        Do not use albums outside the provided candidate list.
        Do not analyze the source facts again.
        Only repair the previous response so it matches the required schema.
        If no recommendation can be recovered, return {"recommendations":[]}.
        """
    }

    private static func repairPrompt(
        invalidResponse: String,
        validationFailure: RecommendationValidationFailure,
        context: MonthlyMetalRecommendationContextArtifact,
        limit: Int
    ) -> String {
        """
        The previous recommendation response failed Swift JSON/schema validation.

        Validation issues:
        \(validationFailure.issues.map { "- \($0)" }.joined(separator: "\n"))

        Candidate identities allowed:
        \(context.candidates.map { "- \($0.bandName) - \($0.albumTitle)" }.joined(separator: "\n"))

        Required shape:
        {
          "recommendations": [
            {
              "rank": 1,
              "bandName": "Band exactly as provided",
              "albumTitle": "Album exactly as provided",
              "decision": "must_check",
              "confidence": 0.9,
              "fitReasons": ["Reason based only on provided facts"],
              "cautionReasons": [],
              "purchaseNotes": null,
              "evidence": ["Concrete provided fact or source evidence"]
            }
          ]
        }

        Allowed decision values:
        must_check, likely_interesting, maybe, skip

        Maximum recommendations: \(limit)

        Invalid response to repair:
        \(invalidResponse)
        """
    }

    private static func validateRecommendations(
        from response: String,
        context: MonthlyMetalRecommendationContextArtifact,
        limit: Int
    ) -> Result<[MonthlyMetalRecommendation], RecommendationValidationFailure> {
        let payload = jsonPayload(from: response)
        let data = Data(payload.utf8)
        let envelope: LLMRecommendationEnvelope

        do {
            envelope = try JSONDecoder().decode(LLMRecommendationEnvelope.self, from: data)
        } catch {
            return .failure(RecommendationValidationFailure(
                payload: payload,
                issues: [
                    "Response must be valid JSON object with top-level recommendations array. Decode error: \(error)"
                ]
            ))
        }

        var issues: [String] = []
        var seenIdentities = Set<MonthlyMetalReleaseIdentity>()
        var seenRanks = Set<Int>()
        let allowedIdentities = Set(context.candidates.map {
            MonthlyMetalReleaseIdentity(bandName: $0.bandName, albumTitle: $0.albumTitle)
        })
        var recommendations: [MonthlyMetalRecommendation] = []

        if envelope.recommendations.count > limit {
            issues.append("recommendations must contain at most \(limit) items")
        }

        for (index, draft) in envelope.recommendations.enumerated() {
            let prefix = "recommendations[\(index)]"

            guard let rank = draft.rank,
                  rank > 0
            else {
                issues.append("\(prefix).rank must be a positive integer")
                continue
            }

            guard seenRanks.insert(rank).inserted else {
                issues.append("\(prefix).rank must be unique")
                continue
            }

            guard let bandName = nonEmpty(draft.bandName) else {
                issues.append("\(prefix).bandName must be a non-empty string")
                continue
            }

            guard let albumTitle = nonEmpty(draft.albumTitle) else {
                issues.append("\(prefix).albumTitle must be a non-empty string")
                continue
            }

            let identity = MonthlyMetalReleaseIdentity(
                bandName: bandName,
                albumTitle: albumTitle
            )

            guard allowedIdentities.contains(identity) else {
                issues.append("\(prefix) must reference a candidate from the input context")
                continue
            }

            guard seenIdentities.insert(identity).inserted else {
                issues.append("\(prefix) duplicates \(bandName) - \(albumTitle)")
                continue
            }

            guard let decisionText = nonEmpty(draft.decision),
                  let decision = MonthlyMetalRecommendationDecision(rawValue: decisionText)
            else {
                issues.append("\(prefix).decision must be one of: must_check, likely_interesting, maybe, skip")
                continue
            }

            guard let confidence = draft.confidence,
                  confidence >= 0,
                  confidence <= 1
            else {
                issues.append("\(prefix).confidence must be a number between 0 and 1")
                continue
            }

            let fitReasons = nonEmptyList(draft.fitReasons)
            let cautionReasons = nonEmptyList(draft.cautionReasons)
            let evidence = nonEmptyList(draft.evidence)

            guard !fitReasons.isEmpty else {
                issues.append("\(prefix).fitReasons must contain at least one non-empty string")
                continue
            }

            guard !evidence.isEmpty else {
                issues.append("\(prefix).evidence must contain at least one non-empty string")
                continue
            }

            recommendations.append(MonthlyMetalRecommendation(
                rank: rank,
                bandName: bandName,
                albumTitle: albumTitle,
                decision: decision,
                confidence: confidence,
                fitReasons: fitReasons,
                cautionReasons: cautionReasons,
                purchaseNotes: nonEmpty(draft.purchaseNotes),
                evidence: evidence
            ))
        }

        if !issues.isEmpty {
            return .failure(RecommendationValidationFailure(payload: payload, issues: issues))
        }

        return .success(recommendations.sorted { $0.rank < $1.rank })
    }

    private static func prettyJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let json = String(data: try encoder.encode(value), encoding: .utf8) else {
            throw MonthlyMetalError.invalidOperation("Unable to encode recommendation context.")
        }

        return json
    }

    private static func combinedRawResponse(first: String, repair: String) -> String {
        """
        --- initial response ---
        \(first)

        --- repair response ---
        \(repair)
        """
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

    private static func nonEmptyList(_ values: [String]?) -> [String] {
        values?.compactMap(nonEmpty) ?? []
    }
}

private struct LLMRecommendationEnvelope: Decodable {
    let recommendations: [LLMRecommendationDraft]
}

private struct LLMRecommendationDraft: Decodable {
    let rank: Int?
    let bandName: String?
    let albumTitle: String?
    let decision: String?
    let confidence: Double?
    let fitReasons: [String]?
    let cautionReasons: [String]?
    let purchaseNotes: String?
    let evidence: [String]?
}

private struct RecommendationValidationFailure: Error, CustomStringConvertible {
    let payload: String
    let issues: [String]

    var description: String {
        issues.joined(separator: "; ")
    }
}
