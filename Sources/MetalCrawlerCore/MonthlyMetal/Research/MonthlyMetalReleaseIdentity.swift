import Foundation

struct MonthlyMetalReleaseIdentity: Hashable, Sendable {
    let bandName: String
    let albumTitle: String

    init(bandName: String, albumTitle: String) {
        self.bandName = Self.normalize(bandName)
        self.albumTitle = Self.normalize(albumTitle)
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(
                of: #"[^a-z0-9]+"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
