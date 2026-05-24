import Foundation

struct MetalArchivesAlbumPageExtractor: Sendable {
    static let shared = MetalArchivesAlbumPageExtractor()

    private let dateFormatter: MonthlyMetalDateFormatter
    private let htmlTextExtractor: HTMLTextExtractor

    private init(
        dateFormatter: MonthlyMetalDateFormatter = .shared,
        htmlTextExtractor: HTMLTextExtractor = .shared
    ) {
        self.dateFormatter = dateFormatter
        self.htmlTextExtractor = htmlTextExtractor
    }

    func extract(from page: CrawledPage) -> ReleaseCandidate? {
        guard let html = page.html else {
            return nil
        }

        guard let title = extractTitle(from: html) else {
            return nil
        }

        let bandName = extractBandName(from: html)
        let albumTitle = extractAlbumTitle(from: html, fallbackTitle: title)

        guard let bandName, let albumTitle else {
            return nil
        }

        let releaseDate = extractReleaseDate(from: html)

        return ReleaseCandidate(
            bandName: bandName,
            albumTitle: albumTitle,
            releaseDate: releaseDate,
            country: nil,
            genre: nil,
            formationDate: nil,
            history: nil,
            confidence: 0.9,
            sources: [
                SourceReference(name: "metal_archives", url: page.finalURL)
            ]
        )
    }

    private func extractTitle(from html: String) -> String? {
        htmlTextExtractor.title(from: html)
    }

    private func extractBandName(from html: String) -> String? {
        if let value = firstMatch(
            in: html,
            pattern: #"<h1[^>]*class="band_name"[^>]*>\s*<a[^>]*>(.*?)</a>\s*</h1>"#
        ) {
            return cleanHTML(value)
        }

        if let value = firstMatch(
            in: html,
            pattern: #"<a[^>]*href="[^"]*/bands/[^"]*"[^>]*>(.*?)</a>"#
        ) {
            return cleanHTML(value)
        }

        return nil
    }

    private func extractAlbumTitle(from html: String, fallbackTitle: String) -> String? {
        if let value = firstMatch(
            in: html,
            pattern: #"<h1[^>]*class="album_name"[^>]*>\s*<a[^>]*>(.*?)</a>\s*</h1>"#
        ) {
            return cleanHTML(value)
        }

        if fallbackTitle.contains(" - ") {
            return fallbackTitle
                .split(separator: "-", maxSplits: 1)
                .last
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        return nil
    }

    private func extractReleaseDate(from html: String) -> Date? {
        guard let value = labeledValue("Release date", in: html) else {
            return nil
        }

        return dateFormatter.parse(value)
    }

    private func extractAlbumType(from html: String) -> AlbumType? {
        guard let value = labeledValue("Type", in: html)?.lowercased() else {
            return nil
        }

        if value.contains("full-length") {
            return .fullLength
        }

        if value == "ep" || value.contains("ep") {
            return .ep
        }

        if value.contains("demo") {
            return .demo
        }

        if value.contains("single") {
            return .single
        }

        if value.contains("split") {
            return .split
        }

        if value.contains("live") {
            return .live
        }

        if value.contains("compilation") {
            return .compilation
        }

        return .unknown
    }

    private func labeledValue(_ label: String, in html: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: label)

        let patterns = [
            #"<dt>\s*\#(escaped):?\s*</dt>\s*<dd[^>]*>(.*?)</dd>"#,
            #"<span[^>]*>\s*\#(escaped):?\s*</span>\s*([^<]+)"#,
            #"\#(escaped):\s*</[^>]+>\s*<[^>]+>(.*?)</"#
        ]

        for pattern in patterns {
            if let value = firstMatch(in: html, pattern: pattern) {
                return cleanHTML(value)
            }
        }

        return nil
    }

    private func firstMatch(in html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        return String(html[captureRange])
    }

    private func cleanHTML(_ value: String) -> String {
        value
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
