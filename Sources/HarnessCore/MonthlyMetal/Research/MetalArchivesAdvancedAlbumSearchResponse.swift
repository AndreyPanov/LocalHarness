import Foundation

struct MetalArchivesAdvancedAlbumSearchResponse: Decodable, Sendable {
    let iTotalRecords: Int
    let iTotalDisplayRecords: Int
    let aaData: [[String]]
}

struct MetalArchivesAdvancedAlbumSearchExtractor: Sendable {
    func albumURLs(from response: MetalArchivesAdvancedAlbumSearchResponse) -> [URL] {
        response.aaData.compactMap { row in
            guard row.count > 1 else {
                return nil
            }

            return albumURL(fromAlbumColumnHTML: row[1])
        }
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
}
