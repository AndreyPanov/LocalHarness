import ArgumentParser
import Foundation
import LocalLLMKit
import MetalCrawlerCore

struct CrawlMetalCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "crawl-metal",
        abstract: "Build a monthly metal crawler candidate list."
    )

    @Option(help: "Month to crawl, formatted as YYYY-MM.")
    var month: String

    @Flag(help: "Skip local LLM extraction from source items.")
    var skipSourceExtraction = false

    @Option(help: "OpenAI-compatible local LLM base URL.")
    var llmBaseURL = LocalLLMModelPreset.sourceExtraction14B.baseURL.absoluteString

    @Option(help: "Model name sent to the local LLM server. Defaults to LOCAL_METAL_CRAWLER_LLM_MODEL or the source extraction 14B preset.")
    var llmModel: String?

    @Option(help: "Temperature for source candidate extraction.")
    var llmTemperature: Double = 0

    @Option(help: "Maximum completion tokens for source candidate extraction.")
    var llmMaxTokens: Int = 4096

    @Option(help: "Request timeout in seconds for source candidate extraction.")
    var llmTimeout: Double = 300

    func run() async throws {
        let crawler = MonthlyMetalCrawler()
        let result = try await crawler.listCandidates(
            month: month,
            sourceExtraction: try sourceExtractionConfiguration()
        )

        print("Monthly metal crawler candidates for \(month)")
        print("Source items crawled: \(result.sourceItems.count)")
        print("Source items extracted: \(result.extractedSourceItemCount)")
        print("Extracted candidate mentions: \(result.extractedCandidateMentionCount)")
        print("Deduplicated potential candidates: \(result.potentialCandidates.count)")
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
        print("Potential candidate artifact: \(result.potentialCandidatesArtifactURL.path)")
        print("Source item artifact: \(result.sourceItemsArtifactURL.path)")

        if let sourceExtractionArtifactURL = result.sourceExtractionArtifactURL {
            print("Source extracted candidates: \(sourceExtractionArtifactURL.path)")
        }
    }

    private func sourceExtractionConfiguration() throws -> MonthlyMetalSourceExtractionConfiguration? {
        guard !skipSourceExtraction else {
            return nil
        }

        guard let baseURL = URL(string: llmBaseURL) else {
            throw ValidationError("Invalid --llm-base-url: \(llmBaseURL)")
        }

        return MonthlyMetalSourceExtractionConfiguration(
            baseURL: baseURL,
            model: llmModel
                ?? ProcessInfo.processInfo.environment["LOCAL_METAL_CRAWLER_LLM_MODEL"]
                ?? LocalLLMModelPreset.sourceExtraction14B.model,
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
