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

    func run() async throws {
        let scout = MonthlyMetalScout()
        let result = try await scout.listCandidates(month: month)

        print("Monthly metal candidates for \(month)")
        print("Found: \(result.candidates.count)")
        print("")

        if result.candidates.isEmpty {
            print("No candidates found.")
        } else {
            for candidate in result.candidates {
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
                    print("  Metal Archives: not matched")
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
        print("Candidate artifact: \(result.candidateArtifactURL.path)")
        print("Editorial source documents: \(result.editorialDocumentsArtifactURL.path)")
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
