import Foundation

public struct MetalArchivesAlbumPageExtractor: MetalArchivesAlbumExtracting {
    public static let shared = MetalArchivesAlbumPageExtractor()

    public init() {}

    public func extractAlbum(from page: SocialSourcePage) -> MetalArchivesAlbum? {
        guard let html = page.html else {
            return nil
        }

        return extractAlbum(from: html, finalURL: page.finalURL)
    }

    public func extractAlbum(from html: String, finalURL: URL?) -> MetalArchivesAlbum? {
        guard let title = title(from: html) else {
            return nil
        }

        let bandName = extractBandName(from: html)
        let albumTitle = extractAlbumTitle(from: html, fallbackTitle: title)

        guard let bandName, let albumTitle else {
            return nil
        }

        let releaseDateText = labeledValue("Release date", in: html)

        return MetalArchivesAlbum(
            bandName: bandName,
            albumTitle: albumTitle,
            albumURL: finalURL,
            releaseType: labeledValue("Type", in: html),
            labelName: labeledValue("Label", in: html),
            releaseDate: releaseDateText.flatMap(MetalArchivesDateFormatter.shared.parse),
            releaseDateText: releaseDateText
        )
    }

    private func title(from html: String) -> String? {
        firstMatch(in: html, pattern: #"<title[^>]*>([\s\S]*?)</title>"#)
            .map(cleanHTML)
    }

    private func extractBandName(from html: String) -> String? {
        if let value = firstMatch(
            in: html,
            pattern: #"<h[1-6][^>]*class\s*=\s*["'][^"']*\bband_name\b[^"']*["'][^>]*>\s*<a[^>]*>(.*?)</a>\s*</h[1-6]>"#
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
            pattern: #"<h[1-6][^>]*class\s*=\s*["'][^"']*\balbum_name\b[^"']*["'][^>]*>\s*<a[^>]*>(.*?)</a>\s*</h[1-6]>"#
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

    private func labeledValue(_ label: String, in html: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: label)
        let patterns = [
            #"<dt[^>]*>\s*\#(escaped):?\s*</dt>\s*<dd[^>]*>(.*?)</dd>"#,
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
}

public struct MetalArchivesAdvancedAlbumSearchExtractor: Sendable {
    public init() {}

    public func albums(
        from response: MetalArchivesAdvancedAlbumSearchResponse
    ) -> [MetalArchivesAdvancedAlbumSearchResult] {
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

    public func albumURLs(
        from response: MetalArchivesAdvancedAlbumSearchResponse
    ) -> [URL] {
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
            return MetalArchivesDateFormatter.shared.parse(normalizedDate)
        }

        guard let text = releaseDateText(fromDateColumnHTML: html) else {
            return nil
        }

        return MetalArchivesDateFormatter.shared.parse(text)
    }

    private func releaseDateText(fromDateColumnHTML html: String) -> String? {
        let text = cleanHTML(html)
        return text.isEmpty ? nil : text
    }
}

public struct MetalArchivesAdvancedAlbumSearchClient: MetalArchivesAlbumSearching {
    private let fetcher: any SocialSourceFetching
    private let extractor: MetalArchivesAdvancedAlbumSearchExtractor
    private let pageSize: Int
    private let includedReleaseTypes: Set<String>

    public init(
        fetcher: any SocialSourceFetching = URLSessionSocialSourceFetcher(),
        extractor: MetalArchivesAdvancedAlbumSearchExtractor = MetalArchivesAdvancedAlbumSearchExtractor(),
        pageSize: Int = 200,
        includedReleaseTypes: Set<String> = ["full-length", "ep"]
    ) {
        self.fetcher = fetcher
        self.extractor = extractor
        self.pageSize = pageSize
        self.includedReleaseTypes = Set(includedReleaseTypes.map { $0.lowercased() })
    }

    public func albums(
        for month: Date
    ) async throws -> [MetalArchivesAdvancedAlbumSearchResult] {
        var albums: [MetalArchivesAdvancedAlbumSearchResult] = []
        var seen = Set<URL>()
        var start = 0

        while true {
            let response = try await searchPage(for: month, start: start)
            let pageAlbums = extractor.albums(from: response)
            let includedPageAlbums = pageAlbums.filter(isIncludedReleaseType)

            for album in includedPageAlbums where !seen.contains(album.albumURL) {
                seen.insert(album.albumURL)
                albums.append(album)
            }

            start += pageSize

            if start >= response.iTotalDisplayRecords || pageAlbums.isEmpty {
                break
            }
        }

        return albums
    }

    public func albumURLs(for month: Date) async throws -> [URL] {
        let albums = try await albums(for: month)
        return albums.map(\.albumURL)
    }

    public func searchURL(for month: Date) -> URL {
        searchURL(for: month, start: 0, pageSize: pageSize)
    }

    public func searchURL(for month: Date, start: Int, pageSize: Int) -> URL {
        let components = monthUTC(month)
        let year = components.year!
        let monthNumber = components.month!

        var urlComponents = URLComponents(
            string: "https://www.metal-archives.com/search/ajax-advanced/searching/albums/"
        )!
        urlComponents.queryItems = [
            URLQueryItem(name: "releaseYearFrom", value: "\(year)"),
            URLQueryItem(name: "releaseMonthFrom", value: String(format: "%02d", monthNumber)),
            URLQueryItem(name: "releaseYearTo", value: "\(year)"),
            URLQueryItem(name: "releaseMonthTo", value: String(format: "%02d", monthNumber)),
            URLQueryItem(name: "releaseType[]", value: "1"),
            URLQueryItem(name: "releaseType[]", value: "5"),
            URLQueryItem(name: "iDisplayStart", value: "\(start)"),
            URLQueryItem(name: "iDisplayLength", value: "\(pageSize)")
        ]

        return urlComponents.url!
    }

    private func searchPage(
        for month: Date,
        start: Int
    ) async throws -> MetalArchivesAdvancedAlbumSearchResponse {
        let url = searchURL(for: month, start: start, pageSize: pageSize)
        let page = try await fetcher.fetch(SocialSourceRequest(
            url: url,
            sourceKind: "metal_archives_advanced_album_search"
        ))
        let json = page.html ?? page.text

        do {
            return try JSONDecoder().decode(
                MetalArchivesAdvancedAlbumSearchResponse.self,
                from: Data(json.utf8)
            )
        } catch {
            throw MetalArchivesError.invalidSearchResponse(url)
        }
    }

    private func isIncludedReleaseType(
        _ album: MetalArchivesAdvancedAlbumSearchResult
    ) -> Bool {
        includedReleaseTypes.contains(album.releaseType.lowercased())
    }
}

private struct MetalArchivesDateFormatter: Sendable {
    static let shared = MetalArchivesDateFormatter()

    func parse(_ rawValue: String) -> Date? {
        let value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"(\d+)(st|nd|rd|th)"#,
                with: "$1",
                options: .regularExpression
            )

        if let date = Self.formatter(dateFormat: "yyyy-MM-dd").date(from: value) {
            return date
        }

        if let date = Self.formatter(dateFormat: "MMMM d, yyyy").date(from: value) {
            return date
        }

        return nil
    }

    private static func formatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = dateFormat
        return formatter
    }
}

private func monthUTC(_ date: Date) -> DateComponents {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.dateComponents([.year, .month], from: date)
}

private func firstMatch(in value: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    ) else {
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
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
