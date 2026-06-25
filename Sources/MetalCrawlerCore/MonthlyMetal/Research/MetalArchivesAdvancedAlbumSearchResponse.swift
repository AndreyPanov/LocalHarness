import Foundation

struct MetalArchivesAdvancedAlbumSearchResponse: Decodable, Sendable {
    let iTotalRecords: Int
    let iTotalDisplayRecords: Int
    let aaData: [[String]]
}

struct MetalArchivesAdvancedAlbumSearchResult: Hashable, Sendable {
    let bandName: String
    let albumTitle: String
    let albumURL: URL
    let releaseType: String
    let releaseDate: Date?
    let releaseDateText: String?
}

struct MetalArchivesAdvancedAlbumSearchExtractor: Sendable {
    private let dateFormatter = MonthlyMetalDateFormatter.shared

    func albums(from response: MetalArchivesAdvancedAlbumSearchResponse) -> [MetalArchivesAdvancedAlbumSearchResult] {
        response.aaData.compactMap { row in
            guard row.count > 3,
                  let albumURL = albumURL(fromAlbumColumnHTML: row[1])
            else {
                return nil
            }

            return MetalArchivesAdvancedAlbumSearchResult(
                bandName: cleanHTML(row[0]),
                albumTitle: cleanHTML(row[1]),
                albumURL: albumURL,
                releaseType: cleanHTML(row[2]),
                releaseDate: releaseDate(fromDateColumnHTML: row[3]),
                releaseDateText: releaseDateText(fromDateColumnHTML: row[3])
            )
        }
    }

    func albumURLs(from response: MetalArchivesAdvancedAlbumSearchResponse) -> [URL] {
        albums(from: response).map(\.albumURL)
    }

    private func albumURL(fromAlbumColumnHTML html: String) -> URL? {
        guard let match = firstMatch(
            in: html,
            pattern: #"href\s*=\s*["']([^"']*/albums/[^"']+)["']"#
        ) else {
            return nil
        }

        return URL(string: match)
    }

    private func releaseDate(fromDateColumnHTML html: String) -> Date? {
        if let normalizedDate = firstMatch(in: html, pattern: #"<!--\s*(\d{4}-\d{2}-\d{2})\s*-->"#),
           !normalizedDate.hasSuffix("-00")
        {
            return dateFormatter.parse(normalizedDate)
        }

        guard let text = releaseDateText(fromDateColumnHTML: html) else {
            return nil
        }

        return dateFormatter.parse(text)
    }

    private func releaseDateText(fromDateColumnHTML html: String) -> String? {
        let text = cleanHTML(html)
        return text.isEmpty ? nil : text
    }

    private func firstMatch(in value: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)

        guard let match = regex.firstMatch(in: value, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: value)
        else {
            return nil
        }

        return String(value[captureRange])
    }

    private func cleanHTML(_ value: String) -> String {
        value
            .replacingOccurrences(
                of: #"<!--[\s\S]*?-->"#,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"<[^>]+>"#,
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
