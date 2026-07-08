import Foundation

public struct BandcampSourceLinkExtractor: BandcampSourceLinkExtracting {
    public init() {}

    public func bandcampSourceLinks(from text: String) -> [BandcampSourceLink] {
        let lines = text.components(separatedBy: .newlines)
        var seen = Set<URL>()
        var links: [BandcampSourceLink] = []

        for (index, line) in lines.enumerated() {
            for rawURL in rawURLs(in: line) {
                guard let url = normalizedURL(from: rawURL),
                      let kind = kind(for: url),
                      seen.insert(url).inserted
                else {
                    continue
                }

                links.append(BandcampSourceLink(
                    url: url,
                    kind: kind,
                    context: context(around: index, in: lines)
                ))
            }
        }

        return links
    }

    public func bandcampSourceLinks(
        from text: String,
        bandName: String,
        albumTitle: String,
        evidence: String?
    ) -> [BandcampSourceLink] {
        bandcampSourceLinks(from: text)
            .compactMap { link -> (BandcampSourceLink, Int)? in
                let score = score(
                    link,
                    bandName: bandName,
                    albumTitle: albumTitle,
                    evidence: evidence
                )

                return score > 0 ? (link, score) : nil
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }

                return lhs.0.url.absoluteString < rhs.0.url.absoluteString
            }
            .map(\.0)
    }

    private func rawURLs(in line: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"https?://[^\s<>"']+"#,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)

        return regex.matches(in: line, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: line) else {
                return nil
            }

            return String(line[matchRange])
        }
    }

    private func normalizedURL(from rawURL: String) -> URL? {
        let cleaned = rawURL
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n.,);]}>\"'"))

        guard let url = URL(string: cleaned) else {
            return nil
        }

        return urlWithoutQueryOrFragment(url)
    }

    private func kind(for url: URL) -> BandcampSourceLinkKind? {
        guard let host = url.host?.lowercased() else {
            return nil
        }

        if host == "bfan.link" || host.hasSuffix(".bfan.link") {
            return .redirect
        }

        guard host == "bandcamp.com" || host.hasSuffix(".bandcamp.com") else {
            return nil
        }

        if url.pathComponents.contains("album") {
            return .album
        }

        if url.pathComponents.contains("track") {
            return .track
        }

        return .artist
    }

    private func context(around index: Int, in lines: [String]) -> String {
        let lowerBound = max(lines.startIndex, index - 5)
        let upperBound = min(lines.endIndex - 1, index + 1)

        return lines[lowerBound...upperBound]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func score(
        _ link: BandcampSourceLink,
        bandName: String,
        albumTitle: String,
        evidence: String?
    ) -> Int {
        let context = normalizedBandcampIdentity(link.context)
        let url = normalizedBandcampIdentity(link.url.absoluteString)
        let band = normalizedBandcampIdentity(bandName)
        let album = normalizedBandcampIdentity(albumTitle)
        let evidence = evidence.map(normalizedBandcampIdentity) ?? ""
        var score = 0

        if !album.isEmpty, context.contains(album) {
            score += 5
        }

        if !album.isEmpty, url.contains(album) {
            score += 5
        }

        if !band.isEmpty, context.contains(band) {
            score += 2
        }

        if !band.isEmpty, url.contains(band) {
            score += 1
        }

        if !evidence.isEmpty, context.contains(evidence) {
            score += 3
        }

        return score
    }
}

public struct BandcampSearchExtractor: Sendable {
    public init() {}

    public func albums(from html: String) -> [BandcampSearchResult] {
        let rows = allBandcampMatches(
            in: html,
            pattern: #"<li[^>]*class\s*=\s*["'][^"']*\bsearchresult\b[^"']*["'][^>]*>([\s\S]*?)</li>"#
        )
        let sourceRows = rows.isEmpty ? [html] : rows

        var seen = Set<URL>()
        var results: [BandcampSearchResult] = []

        for row in sourceRows {
            guard let albumURL = albumURL(from: row),
                  seen.insert(albumURL).inserted
            else {
                continue
            }

            let albumTitle = albumTitle(from: row, albumURL: albumURL)
                ?? albumTitle(from: albumURL)

            guard let albumTitle,
                  !albumTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }

            results.append(BandcampSearchResult(
                bandName: bandName(from: row),
                albumTitle: albumTitle,
                albumURL: albumURL
            ))
        }

        return results
    }

    private func albumURL(from html: String) -> URL? {
        guard let value = firstBandcampMatch(
            in: html,
            pattern: #"href\s*=\s*["']([^"']+/album/[^"']+)["']"#
        ) else {
            return nil
        }

        return URL(string: value).map(urlWithoutQueryOrFragment)
    }

    private func albumTitle(from html: String, albumURL: URL) -> String? {
        let escapedURL = NSRegularExpression.escapedPattern(for: albumURL.absoluteString)
        let patterns = [
            #"<a[^>]*href\s*=\s*["']\#(escapedURL)["'][^>]*>([\s\S]*?)</a>"#,
            #"<div[^>]*class\s*=\s*["'][^"']*\bheading\b[^"']*["'][^>]*>\s*<a[^>]*>([\s\S]*?)</a>"#
        ]

        for pattern in patterns {
            if let value = firstBandcampMatch(in: html, pattern: pattern) {
                let cleaned = cleanBandcampHTML(value)

                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return nil
    }

    private func albumTitle(from url: URL) -> String? {
        guard let slug = url.pathComponents.last else {
            return nil
        }

        return slug
            .split(separator: "-")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private func bandName(from html: String) -> String? {
        let patterns = [
            #"<div[^>]*class\s*=\s*["'][^"']*\bsubhead\b[^"']*["'][^>]*>([\s\S]*?)</div>"#,
            #"<div[^>]*class\s*=\s*["'][^"']*\bitemsubtext\b[^"']*["'][^>]*>([\s\S]*?)</div>"#
        ]

        for pattern in patterns {
            guard let value = firstBandcampMatch(in: html, pattern: pattern) else {
                continue
            }

            let cleaned = cleanBandcampHTML(value)
                .replacingOccurrences(
                    of: #"^\s*by\s+"#,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty {
                return cleaned
            }
        }

        return nil
    }
}

public struct BandcampAlbumPageExtractor: BandcampAlbumAvailabilityExtracting {
    public static let shared = BandcampAlbumPageExtractor()

    public init() {}

    private struct CDAvailabilityFacts {
        let hasCD: Bool
        let isAvailable: Bool
        let text: String?
    }

    public func extractBandcampAvailability(from page: SocialSourcePage) -> BandcampAlbumAvailability? {
        guard let html = page.html else {
            return nil
        }

        return extractBandcampAvailability(from: html, finalURL: page.finalURL)
    }

    public func extractBandcampAvailability(
        from html: String,
        finalURL: URL?
    ) -> BandcampAlbumAvailability? {
        guard let finalURL else {
            return nil
        }

        let text = cleanBandcampHTML(html)
        let lowercasedText = text.lowercased()
        let hasDigital = lowercasedText.contains("digital album")
            || lowercasedText.contains("buy digital")
            || lowercasedText.contains("high-quality download")
        let digitalFormats = digitalFormats(from: text)
        let digitalQualityText = digitalQualityText(from: text)
        let cdAvailability = cdAvailabilityFacts(from: html, pageText: text)

        return BandcampAlbumAvailability(
            bandName: bandName(from: html),
            albumTitle: albumTitle(from: html),
            albumURL: finalURL,
            hasDigital: hasDigital,
            digitalFormats: digitalFormats,
            digitalQualityText: digitalQualityText,
            isHiResAvailable: isHiResAvailable(from: digitalQualityText),
            hasCD: cdAvailability.hasCD,
            isCDAvailable: cdAvailability.isAvailable,
            cdAvailabilityText: cdAvailability.text
        )
    }

    private func albumTitle(from html: String) -> String? {
        let patterns = [
            #"<h2[^>]*class\s*=\s*["'][^"']*\btrackTitle\b[^"']*["'][^>]*>([\s\S]*?)</h2>"#,
            #"<meta[^>]*property\s*=\s*["']og:title["'][^>]*content\s*=\s*["']([^"']+)["']"#
        ]

        for pattern in patterns {
            if let value = firstBandcampMatch(in: html, pattern: pattern) {
                let cleaned = cleanBandcampHTML(value)

                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return nil
    }

    private func bandName(from html: String) -> String? {
        let patterns = [
            #"<span[^>]*itemprop\s*=\s*["']byArtist["'][^>]*>([\s\S]*?)</span>"#,
            #"<a[^>]*class\s*=\s*["'][^"']*\bband-name\b[^"']*["'][^>]*>([\s\S]*?)</a>"#,
            #"by\s+<a[^>]*>([\s\S]*?)</a>"#
        ]

        for pattern in patterns {
            if let value = firstBandcampMatch(in: html, pattern: pattern) {
                let cleaned = cleanBandcampHTML(value)

                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        return nil
    }

    private func digitalFormats(from text: String) -> [String] {
        let formats = [
            "FLAC",
            "ALAC",
            "WAV",
            "AIFF",
            "MP3",
            "AAC",
            "Ogg Vorbis"
        ]

        return formats.filter { format in
            text.range(
                of: #"\b\#(NSRegularExpression.escapedPattern(for: format))\b"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    private func digitalQualityText(from text: String) -> String? {
        if let value = firstBandcampMatch(
            in: text,
            pattern: #"\b(\d{2}\s*[- ]?bit(?:\s*/\s*|\s+)?(?:\d+(?:\.\d+)?)?\s*kHz)\b"#
        ) {
            return value
        }

        if let value = firstBandcampMatch(
            in: text,
            pattern: #"(high-quality download[^.]+)"#
        ) {
            return value
        }

        return nil
    }

    private func isHiResAvailable(from qualityText: String?) -> Bool? {
        guard let qualityText else {
            return nil
        }

        if firstBandcampMatch(in: qualityText, pattern: #"\b(24)\s*[- ]?bit\b"#) != nil {
            return true
        }

        if let sampleRate = firstBandcampMatch(
            in: qualityText,
            pattern: #"\b(\d+(?:\.\d+)?)\s*kHz\b"#
        ).flatMap(Double.init) {
            return sampleRate > 48
        }

        if firstBandcampMatch(in: qualityText, pattern: #"\b(16)\s*[- ]?bit\b"#) != nil {
            return false
        }

        return nil
    }

    private func containsCD(in text: String) -> Bool {
        text.range(of: #"compact\s+disc"#, options: [.regularExpression, .caseInsensitive]) != nil
            || text.range(of: #"\bCD\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func isSoldOut(_ text: String) -> Bool {
        text.range(of: #"sold\s+out|not\s+available"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func cdAvailabilityFacts(from html: String, pageText: String) -> CDAvailabilityFacts {
        let cdBlocks = buyItemBlocks(from: html)
            .map { block in (html: block, text: cleanBandcampHTML(block)) }
            .filter { containsCD(in: $0.text) }

        if let availableBlock = cdBlocks.first(where: { !isSoldOut($0.text) }) {
            return CDAvailabilityFacts(
                hasCD: true,
                isAvailable: true,
                text: cdAvailabilitySummary(from: availableBlock.html, fallbackText: availableBlock.text)
            )
        }

        if let unavailableBlock = cdBlocks.first {
            return CDAvailabilityFacts(
                hasCD: true,
                isAvailable: false,
                text: cdAvailabilitySummary(from: unavailableBlock.html, fallbackText: unavailableBlock.text)
            )
        }

        let hasCD = containsCD(in: pageText)

        return CDAvailabilityFacts(
            hasCD: hasCD,
            isAvailable: hasCD && !isSoldOut(pageText),
            text: cdAvailabilityText(from: pageText)
        )
    }

    private func buyItemBlocks(from html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"<([a-z][a-z0-9]*)\b[^>]*class\s*=\s*["'][^"']*\bbuyItem\b[^"']*["'][^>]*>([\s\S]*?)</\1>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 2,
                  let captureRange = Range(match.range(at: 2), in: html)
            else {
                return nil
            }

            return String(html[captureRange])
        }
    }

    private func cdAvailabilitySummary(from html: String, fallbackText: String) -> String? {
        let parts = [
            htmlText(
                from: html,
                pattern: #"<span[^>]*class\s*=\s*["'][^"']*\bbuyItemPackageTitle\b[^"']*["'][^>]*>([\s\S]*?)</span>"#
            ),
            htmlText(
                from: html,
                pattern: #"<div[^>]*class\s*=\s*["'][^"']*\bmerchtype\b[^"']*["'][^>]*>([\s\S]*?)</div>"#
            ),
            firstBandcampMatch(
                in: fallbackText,
                pattern: #"(ships\s+out\s+within\s+\d+\s+\w+)"#
            ),
            firstBandcampMatch(
                in: fallbackText,
                pattern: #"(Buy\s+Compact\s+Disc|Buy\s+CD|Add\s+to\s+cart)"#
            )
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !parts.isEmpty {
            var uniqueParts: [String] = []

            for part in parts where !uniqueParts.contains(part) {
                uniqueParts.append(part)
            }

            return uniqueParts.joined(separator: " | ")
        }

        return cdAvailabilityText(from: fallbackText)
    }

    private func htmlText(from html: String, pattern: String) -> String? {
        guard let value = firstBandcampMatch(in: html, pattern: pattern) else {
            return nil
        }

        let cleaned = cleanBandcampHTML(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func cdAvailabilityText(from text: String) -> String? {
        if let value = firstBandcampMatch(
            in: text,
            pattern: #"(Compact\s+Disc(?:\s*\(CD\))?(?:[^.]{0,120}))"#
        ) {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if containsCD(in: text) {
            return "CD"
        }

        return nil
    }
}

public struct BandcampSearchClient: BandcampAlbumSearching {
    private let fetcher: any SocialSourceFetching
    private let extractor: BandcampSearchExtractor

    public init(
        fetcher: any SocialSourceFetching = URLSessionSocialSourceFetcher(),
        extractor: BandcampSearchExtractor = BandcampSearchExtractor()
    ) {
        self.fetcher = fetcher
        self.extractor = extractor
    }

    public func bandcampAlbums(
        bandName: String,
        albumTitle: String,
        limit: Int = 10
    ) async throws -> [BandcampSearchResult] {
        guard limit > 0 else {
            return []
        }

        let url = bandcampSearchURL(bandName: bandName, albumTitle: albumTitle)
        let page = try await fetcher.fetch(SocialSourceRequest(
            url: url,
            headers: bandcampHeaders,
            sourceKind: "bandcamp_search"
        ))

        return Array(extractor.albums(from: page.html ?? page.text).prefix(limit))
    }

    public func bandcampSearchURL(
        bandName: String,
        albumTitle: String
    ) -> URL {
        var components = URLComponents(string: "https://bandcamp.com/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(bandName) \(albumTitle)"),
            URLQueryItem(name: "item_type", value: "a")
        ]
        return components.url!
    }
}

public struct BandcampAvailabilityClient: BandcampAvailabilityChecking {
    private let fetcher: any SocialSourceFetching
    private let searchClient: any BandcampAlbumSearching
    private let extractor: any BandcampAlbumAvailabilityExtracting

    public init(
        fetcher: any SocialSourceFetching = URLSessionSocialSourceFetcher(),
        searchClient: (any BandcampAlbumSearching)? = nil,
        extractor: any BandcampAlbumAvailabilityExtracting = BandcampAlbumPageExtractor.shared
    ) {
        self.fetcher = fetcher
        self.searchClient = searchClient ?? BandcampSearchClient(fetcher: fetcher)
        self.extractor = extractor
    }

    public func bandcampAvailability(
        bandName: String,
        albumTitle: String
    ) async throws -> BandcampAlbumAvailability? {
        let matches = try await searchClient.bandcampAlbums(
            bandName: bandName,
            albumTitle: albumTitle,
            limit: 10
        )
        guard let match = matches.first(where: { result in
            normalizedBandcampIdentity(result.albumTitle) == normalizedBandcampIdentity(albumTitle)
                && (result.bandName == nil
                    || normalizedBandcampIdentity(result.bandName ?? "") == normalizedBandcampIdentity(bandName))
        }) else {
            return nil
        }

        return try await bandcampAvailability(at: match.albumURL)
    }

    public func bandcampAvailability(at albumURL: URL) async throws -> BandcampAlbumAvailability? {
        let page = try await fetcher.fetch(SocialSourceRequest(
            url: albumURL,
            headers: bandcampHeaders,
            sourceKind: "bandcamp_album"
        ))

        return extractor.extractBandcampAvailability(from: page)
    }
}

private let bandcampHeaders = [
    "user-agent": "Mozilla/5.0"
]

private func firstBandcampMatch(in value: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    ) else {
        return nil
    }

    let range = NSRange(value.startIndex..<value.endIndex, in: value)

    guard let match = regex.firstMatch(in: value, range: range),
          match.numberOfRanges > 1,
          let captureRange = Range(match.range(at: match.numberOfRanges - 1), in: value)
    else {
        return nil
    }

    return String(value[captureRange])
}

private func allBandcampMatches(in value: String, pattern: String) -> [String] {
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

private func cleanBandcampHTML(_ value: String) -> String {
    value
        .replacingOccurrences(
            of: #"<script\b[\s\S]*?</script>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        .replacingOccurrences(
            of: #"<style\b[\s\S]*?</style>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
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

private func urlWithoutQueryOrFragment(_ url: URL) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return url
    }

    components.query = nil
    components.fragment = nil
    return components.url ?? url
}

private func normalizedBandcampIdentity(_ value: String) -> String {
    cleanBandcampHTML(value)
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        .lowercased()
        .replacingOccurrences(
            of: #"[^a-z0-9]+"#,
            with: "",
            options: .regularExpression
        )
}
