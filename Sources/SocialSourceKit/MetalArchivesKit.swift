import Foundation

public struct MetalArchivesAlbumPageExtractor: MetalArchivesAlbumExtracting, MetalArchivesEnrichmentExtracting {
    public static let shared = MetalArchivesAlbumPageExtractor()

    private let currentYear: Int

    public init(currentYear: Int? = nil) {
        self.currentYear = currentYear ?? MetalArchivesAlbumPageExtractor.defaultCurrentYear()
    }

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

    public func extractAlbumEnrichment(from page: SocialSourcePage) -> MetalArchivesAlbumEnrichment? {
        guard let html = page.html else {
            return nil
        }

        return extractAlbumEnrichment(from: html, finalURL: page.finalURL)
    }

    public func extractAlbumEnrichment(from html: String, finalURL: URL?) -> MetalArchivesAlbumEnrichment? {
        guard let album = extractAlbum(from: html, finalURL: finalURL),
              let albumURL = finalURL ?? album.albumURL
        else {
            return nil
        }

        let reviewSummary = labeledValue("Reviews", in: html)
            .map(reviewSummary)

        return MetalArchivesAlbumEnrichment(
            bandName: album.bandName,
            albumTitle: album.albumTitle,
            albumURL: albumURL,
            bandURL: extractBandURL(from: html),
            releaseType: album.releaseType,
            releaseDate: album.releaseDate,
            releaseDateText: album.releaseDateText,
            labelName: album.labelName,
            genre: nil,
            lyricalThemes: nil,
            fullLengthAlbumCount: nil,
            reviewCount: reviewSummary?.reviewCount,
            averageReviewScore: reviewSummary?.averageScore,
            yearsActive: nil,
            fullTimeMemberCount: nil
        )
    }

    public func extractBandEnrichment(from page: SocialSourcePage) -> MetalArchivesBandEnrichment? {
        guard let html = page.html else {
            return nil
        }

        return extractBandEnrichment(from: html, finalURL: page.finalURL)
    }

    public func extractBandEnrichment(from html: String, finalURL: URL?) -> MetalArchivesBandEnrichment? {
        let genre = labeledValue("Genre", in: html)
        let lyricalThemes = labeledValue("Lyrical themes", in: html)
            ?? labeledValue("Themes", in: html)
        let activeYears = yearsActive(
            yearsActiveText: labeledValue("Years active", in: html),
            formedInText: labeledValue("Formed in", in: html),
            statusText: labeledValue("Status", in: html)
        )
        let memberCount = fullTimeMemberCount(fromBandHTML: html)
        let discographyURL = discographyURL(fromBandHTML: html, bandURL: finalURL)

        guard genre != nil
            || lyricalThemes != nil
            || activeYears != nil
            || memberCount != nil
            || discographyURL != nil
        else {
            return nil
        }

        return MetalArchivesBandEnrichment(
            bandURL: finalURL.map(urlWithoutFragment),
            genre: genre,
            lyricalThemes: lyricalThemes,
            yearsActive: activeYears,
            fullTimeMemberCount: memberCount,
            discographyURL: discographyURL
        )
    }

    public func fullLengthAlbumCount(fromDiscographyHTML html: String) -> Int? {
        let rows = allMatches(
            in: html,
            pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#
        )

        if !rows.isEmpty {
            return rows.filter { row in
                cleanHTML(row).range(
                    of: "Full-length",
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }.count
        }

        let directTypeMatches = allMatches(
            in: html,
            pattern: #">\s*(Full-length)\s*<"#
        )

        return directTypeMatches.isEmpty ? nil : directTypeMatches.count
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

    private func extractBandURL(from html: String) -> URL? {
        let patterns = [
            #"<h[1-6][^>]*class\s*=\s*["'][^"']*\bband_name\b[^"']*["'][^>]*>\s*<a[^>]*href\s*=\s*["']([^"']*/bands/[^"']+)["']"#,
            #"<a[^>]*href\s*=\s*["']([^"']*/bands/[^"']+)["'][^>]*>"#
        ]

        for pattern in patterns {
            if let value = firstMatch(in: html, pattern: pattern),
               let url = URL(string: value)
            {
                return urlWithoutFragment(url)
            }
        }

        return nil
    }

    private func reviewSummary(from value: String) -> MetalArchivesReviewSummary {
        let reviewCount = firstMatch(
            in: value,
            pattern: #"(\d+)\s+reviews?"#
        ).flatMap(Int.init)
        let averageScore = firstMatch(
            in: value,
            pattern: #"(?:avg\.\s*)?(\d+(?:\.\d+)?)%"#
        ).flatMap(Double.init)

        return MetalArchivesReviewSummary(
            reviewCount: reviewCount,
            averageScore: averageScore
        )
    }

    private func yearsActive(
        yearsActiveText: String?,
        formedInText: String?,
        statusText: String?
    ) -> Int? {
        let sourceText = yearsActiveText ?? formedInText

        guard let sourceText,
              let startYear = allMatches(in: sourceText, pattern: #"(\d{4})"#).first.flatMap(Int.init)
        else {
            return nil
        }

        let lowercasedYears = sourceText.lowercased()
        let lowercasedStatus = statusText?.lowercased() ?? ""
        let endYear: Int

        if lowercasedYears.contains("present") || lowercasedStatus.contains("active") {
            endYear = currentYear
        } else {
            endYear = allMatches(in: sourceText, pattern: #"(\d{4})"#).last.flatMap(Int.init) ?? currentYear
        }

        return max(0, endYear - startYear)
    }

    private func fullTimeMemberCount(fromBandHTML html: String) -> Int? {
        let currentMembersTable = firstMatch(
            in: html,
            pattern: #"<div[^>]*id\s*=\s*["']band_tab_members_current["'][^>]*>[\s\S]*?<table[^>]*>([\s\S]*?)</table>"#
        ) ?? firstMatch(
            in: html,
            pattern: #"Current lineup[\s\S]*?<table[^>]*>([\s\S]*?)</table>"#
        )

        guard let currentMembersTable else {
            return nil
        }

        let rows = allMatches(
            in: currentMembersTable,
            pattern: #"<tr[^>]*>([\s\S]*?)</tr>"#
        )
        let memberRows = rows.filter { row in
            row.range(
                of: #"/artists/"#,
                options: [.caseInsensitive, .regularExpression]
            ) != nil
        }

        return memberRows.isEmpty ? nil : memberRows.count
    }

    private func discographyURL(fromBandHTML html: String, bandURL: URL?) -> URL? {
        if let value = firstMatch(
            in: html,
            pattern: #"href\s*=\s*["']([^"']*/band/discography/id/\d+/tab/all[^"']*)["']"#
        ), let url = URL(string: value)
        {
            return url
        }

        return bandURL.flatMap(MetalArchivesAlbumPageExtractor.discographyURL)
    }

    fileprivate static func discographyURL(for bandURL: URL) -> URL? {
        guard let bandID = bandURL.pathComponents.last,
              bandID.range(of: #"^\d+$"#, options: .regularExpression) != nil
        else {
            return nil
        }

        return URL(string: "https://www.metal-archives.com/band/discography/id/\(bandID)/tab/all")
    }

    private static func defaultCurrentYear() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.component(.year, from: Date())
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

    public func albums(
        bandName: String,
        albumTitle: String,
        limit: Int = 20
    ) async throws -> [MetalArchivesAdvancedAlbumSearchResult] {
        guard limit > 0 else {
            return []
        }

        let lookupPageSize = min(pageSize, max(1, limit))
        let response = try await searchPage(
            bandName: bandName,
            albumTitle: albumTitle,
            start: 0,
            pageSize: lookupPageSize
        )
        let albums = extractor.albums(from: response)
            .filter(isIncludedReleaseType)

        return Array(albums.prefix(limit))
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

    public func searchURL(
        bandName: String,
        albumTitle: String,
        start: Int,
        pageSize: Int
    ) -> URL {
        var urlComponents = URLComponents(
            string: "https://www.metal-archives.com/search/ajax-advanced/searching/albums/"
        )!
        urlComponents.queryItems = [
            URLQueryItem(name: "bandName", value: bandName),
            URLQueryItem(name: "releaseTitle", value: albumTitle),
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
        return try await searchPage(url: url)
    }

    private func searchPage(
        bandName: String,
        albumTitle: String,
        start: Int,
        pageSize: Int
    ) async throws -> MetalArchivesAdvancedAlbumSearchResponse {
        let url = searchURL(
            bandName: bandName,
            albumTitle: albumTitle,
            start: start,
            pageSize: pageSize
        )
        return try await searchPage(url: url)
    }

    private func searchPage(url: URL) async throws -> MetalArchivesAdvancedAlbumSearchResponse {
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

public struct MetalArchivesEnrichmentClient: MetalArchivesAlbumEnriching {
    private let fetcher: any SocialSourceFetching
    private let extractor: any MetalArchivesAlbumExtracting & MetalArchivesEnrichmentExtracting
    private let searchClient: any MetalArchivesAlbumSearching

    public init(
        fetcher: any SocialSourceFetching = URLSessionSocialSourceFetcher(),
        extractor: any MetalArchivesAlbumExtracting & MetalArchivesEnrichmentExtracting = MetalArchivesAlbumPageExtractor.shared,
        searchClient: (any MetalArchivesAlbumSearching)? = nil
    ) {
        self.fetcher = fetcher
        self.extractor = extractor
        self.searchClient = searchClient ?? MetalArchivesAdvancedAlbumSearchClient(fetcher: fetcher)
    }

    public func enrichAlbum(
        bandName: String,
        albumTitle: String
    ) async throws -> MetalArchivesAlbumEnrichment? {
        let matches = try await searchClient.albums(
            bandName: bandName,
            albumTitle: albumTitle,
            limit: 20
        )
        guard let match = matches.first(where: { match in
            normalizedMetalArchivesIdentity(match.bandName) == normalizedMetalArchivesIdentity(bandName)
                && normalizedMetalArchivesIdentity(match.albumTitle) == normalizedMetalArchivesIdentity(albumTitle)
        }) else {
            return nil
        }

        return try await enrichAlbum(at: match.albumURL)
    }

    public func enrichAlbum(at albumURL: URL) async throws -> MetalArchivesAlbumEnrichment? {
        let albumPage = try await fetcher.fetch(SocialSourceRequest(
            url: albumURL,
            headers: metalArchivesHeaders,
            sourceKind: "metal_archives_album"
        ))

        guard let albumEnrichment = extractor.extractAlbumEnrichment(from: albumPage) else {
            return nil
        }

        let bandEnrichment = await fetchBandEnrichment(for: albumEnrichment)
        let fullLengthAlbumCount = await fetchFullLengthAlbumCount(
            bandURL: albumEnrichment.bandURL,
            bandEnrichment: bandEnrichment
        )

        return MetalArchivesAlbumEnrichment(
            bandName: albumEnrichment.bandName,
            albumTitle: albumEnrichment.albumTitle,
            albumURL: albumEnrichment.albumURL,
            bandURL: albumEnrichment.bandURL ?? bandEnrichment?.bandURL,
            releaseType: albumEnrichment.releaseType,
            releaseDate: albumEnrichment.releaseDate,
            releaseDateText: albumEnrichment.releaseDateText,
            labelName: albumEnrichment.labelName,
            genre: bandEnrichment?.genre,
            lyricalThemes: bandEnrichment?.lyricalThemes,
            fullLengthAlbumCount: fullLengthAlbumCount,
            reviewCount: albumEnrichment.reviewCount,
            averageReviewScore: albumEnrichment.averageReviewScore,
            yearsActive: bandEnrichment?.yearsActive,
            fullTimeMemberCount: bandEnrichment?.fullTimeMemberCount
        )
    }

    private func fetchBandEnrichment(
        for albumEnrichment: MetalArchivesAlbumEnrichment
    ) async -> MetalArchivesBandEnrichment? {
        guard let bandURL = albumEnrichment.bandURL else {
            return nil
        }

        do {
            let page = try await fetcher.fetch(SocialSourceRequest(
                url: bandURL,
                headers: metalArchivesHeaders,
                sourceKind: "metal_archives_band"
            ))
            return extractor.extractBandEnrichment(from: page)
        } catch {
            return nil
        }
    }

    private func fetchFullLengthAlbumCount(
        bandURL: URL?,
        bandEnrichment: MetalArchivesBandEnrichment?
    ) async -> Int? {
        let discographyURL = bandEnrichment?.discographyURL
            ?? bandURL.flatMap(MetalArchivesAlbumPageExtractor.discographyURL)

        guard let discographyURL else {
            return nil
        }

        do {
            let page = try await fetcher.fetch(SocialSourceRequest(
                url: discographyURL,
                headers: metalArchivesHeaders,
                sourceKind: "metal_archives_discography"
            ))
            return extractor.fullLengthAlbumCount(fromDiscographyHTML: page.html ?? page.text)
        } catch {
            return nil
        }
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

private func allMatches(in value: String, pattern: String) -> [String] {
    guard let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    ) else {
        return []
    }

    let range = NSRange(value.startIndex..<value.endIndex, in: value)

    return regex.matches(in: value, range: range).compactMap { match in
        guard match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: value)
        else {
            return nil
        }

        return String(value[captureRange])
    }
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

private func urlWithoutFragment(_ url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return url
    }

    components.fragment = nil
    return components.url ?? url
}

private let metalArchivesHeaders = [
    "user-agent": "Mozilla/5.0"
]

private func normalizedMetalArchivesIdentity(_ value: String) -> String {
    cleanHTML(value)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .lowercased()
        .replacingOccurrences(
            of: #"[^a-z0-9]+"#,
            with: "",
            options: .regularExpression
        )
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
