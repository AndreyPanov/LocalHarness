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
        let result = try await scout.listAlbums(month: month)

        print("Metal Archives releases for \(month)")
        print("Found: \(result.albums.count)")
        print("")

        if result.albums.isEmpty {
            print("No releases found.")
        } else {
            for album in result.albums {
                print("\(album.bandName) - \(album.albumTitle)")
                print("  Type: \(album.releaseType)")

                if let releaseDate = album.releaseDate {
                    print("  Release date: \(Self.dateFormatter.string(from: releaseDate))")
                } else if let releaseDateText = album.releaseDateText {
                    print("  Release date: \(releaseDateText)")
                } else {
                    print("  Release date: unknown")
                }

                print("  Metal Archives: \(album.metalArchivesURL.absoluteString)")
            }
        }

        print("")
        print("Run ID: \(result.runID)")
        print("Run artifacts: \(result.runDirectory.path)")
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
