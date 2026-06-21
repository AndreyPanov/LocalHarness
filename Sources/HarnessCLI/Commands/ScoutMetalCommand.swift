import ArgumentParser
import Foundation
import HarnessCore

struct ScoutMetalCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scout-metal",
        abstract: "Build a monthly metal release report."
    )

    @Option(help: "Month to scout, formatted as YYYY-MM.")
    var month: String

    @Flag(help: "Skip local LLM extraction from editorial source documents.")
    var skipEditorialExtraction = false

    @Option(help: "OpenAI-compatible local LLM base URL.")
    var llmBaseURL = "http://127.0.0.1:8081/v1"

    @Option(help: "Model name sent to the local LLM server. Defaults to LOCAL_HARNESS_LLM_MODEL or the project default.")
    var llmModel: String?

    @Option(help: "Temperature for editorial candidate extraction.")
    var llmTemperature: Double = 0

    @Option(help: "Maximum completion tokens for editorial candidate extraction.")
    var llmMaxTokens: Int = 8192

    @Option(help: "Request timeout in seconds for editorial candidate extraction.")
    var llmTimeout: Double = 300

    func run() async throws {
        let scout = MonthlyMetalScout()
        let result = try await scout.listCandidates(
            month: month,
            editorialExtraction: try editorialExtractionConfiguration()
        )

        print("Monthly metal potential candidates for \(month)")
        print("Catalog candidates: \(result.candidates.count)")
        print("Potential candidates: \(result.potentialCandidates.count)")
        print("")

        if result.potentialCandidates.isEmpty {
            print("No candidates found.")
        } else {
            for candidate in result.potentialCandidates {
                print("\(candidate.bandName) - \(candidate.albumTitle)")
                print("  Type: \(candidate.releaseType ?? "unknown")")

                if let labelName = candidate.labelName {
                    print("  Label: \(labelName)")
                }

                if let releaseDate = candidate.releaseDate {
                    print("  Release date: \(Self.dateFormatter.string(from: releaseDate))")
                } else if let releaseDateText = candidate.releaseDateText {
                    print("  Release date: \(releaseDateText)")
                } else {
                    print("  Release date: unknown")
                }

                if let metalArchivesURL = candidate.metalArchivesURL {
                    print("  Metal Archives: \(metalArchivesURL.absoluteString)")
                } else {
                    print("  Metal Archives: pending enrichment")
                }

                print("  Sources:")

                for source in candidate.sources {
                    var sourceLine = "    - \(source.name) (\(source.kind))"

                    if let rank = source.rank {
                        sourceLine += " #\(rank)"
                    }

                    print(sourceLine)

                    if let sourceURL = source.sourceURL {
                        print("      Source: \(sourceURL.absoluteString)")
                    }

                    if let itemURL = source.itemURL {
                        print("      Item: \(itemURL.absoluteString)")
                    }

                    if let note = source.note {
                        print("      Note: \(note)")
                    }
                }
            }
        }

        print("")
        print("Run ID: \(result.runID)")
        print("Run artifacts: \(result.runDirectory.path)")
        print("Catalog candidate artifact: \(result.candidateArtifactURL.path)")
        print("Potential candidate artifact: \(result.potentialCandidatesArtifactURL.path)")
        print("Editorial source documents: \(result.editorialDocumentsArtifactURL.path)")

        if let editorialExtractionArtifactURL = result.editorialExtractionArtifactURL {
            print("Editorial extracted candidates: \(editorialExtractionArtifactURL.path)")
        }
    }

    private func editorialExtractionConfiguration() throws -> MonthlyMetalLLMExtractionConfiguration? {
        guard !skipEditorialExtraction else {
            return nil
        }

        guard let baseURL = URL(string: llmBaseURL) else {
            throw ValidationError("Invalid --llm-base-url: \(llmBaseURL)")
        }

        return MonthlyMetalLLMExtractionConfiguration(
            baseURL: baseURL,
            model: llmModel
                ?? ProcessInfo.processInfo.environment["LOCAL_HARNESS_LLM_MODEL"]
                ?? "mlx-community/Qwen3.6-35B-A3B-4bit-DWQ",
            temperature: llmTemperature,
            maxTokens: llmMaxTokens,
            requestTimeout: llmTimeout
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
