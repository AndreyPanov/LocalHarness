import Foundation

public struct URLSessionSocialSourceFetcher: SocialSourceFetching {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(_ request: SocialSourceRequest) async throws -> SocialSourcePage {
        var urlRequest = URLRequest(url: request.url)

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: urlRequest)
        let text = String(data: data, encoding: .utf8) ?? ""
        let finalURL = (response as? HTTPURLResponse)?.url ?? request.url

        return SocialSourcePage(
            url: request.url,
            finalURL: finalURL,
            text: text,
            html: text
        )
    }
}

public struct SocialSourceClient: SocialDescriptionProviding {
    private let fetcher: any SocialSourceFetching
    private let youTubeRSSFeedParser: YouTubeRSSFeedParser
    private let youTubeChannelPageParser: YouTubeChannelPageParser
    private let youTubeVideoDescriptionExtractor: YouTubeVideoDescriptionExtractor
    private let instagramFeedParser: InstagramFeedParser

    public init(
        fetcher: any SocialSourceFetching = URLSessionSocialSourceFetcher(),
        youTubeRSSFeedParser: YouTubeRSSFeedParser = YouTubeRSSFeedParser(),
        youTubeChannelPageParser: YouTubeChannelPageParser = YouTubeChannelPageParser(),
        youTubeVideoDescriptionExtractor: YouTubeVideoDescriptionExtractor = YouTubeVideoDescriptionExtractor()
    ) {
        self.fetcher = fetcher
        self.youTubeRSSFeedParser = youTubeRSSFeedParser
        self.youTubeChannelPageParser = youTubeChannelPageParser
        self.youTubeVideoDescriptionExtractor = youTubeVideoDescriptionExtractor
        self.instagramFeedParser = InstagramFeedParser()
    }

    public func getDescription(
        from url: URL,
        type: SocialSourceType
    ) async throws -> String {
        switch type {
        case .youtube:
            let page = try await fetcher.fetch(SocialSourceRequest(url: url))
            guard let description = youTubeVideoDescriptionExtractor.description(from: page.html ?? page.text) else {
                throw SocialSourceError.missingDescription(url)
            }
            return description

        case .instagram:
            throw SocialSourceError.unsupportedDirectDescription(type)
        }
    }

    public func getDescriptions(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType,
        options: SocialSourceOptions = SocialSourceOptions()
    ) async throws -> [String] {
        try await getDescriptionItems(
            from: url,
            dateRange: dateRange,
            type: type,
            options: options
        ).map(\.text)
    }

    public func getDescriptionItems(
        from url: URL,
        dateRange: [Date],
        type: SocialSourceType,
        options: SocialSourceOptions = SocialSourceOptions()
    ) async throws -> [SocialSourceItem] {
        let interval = try dateInterval(from: dateRange)

        switch type {
        case .youtube:
            return try await youtubeItems(
                from: url,
                dateRange: interval,
                options: options
            )

        case .instagram:
            return try await instagramItems(
                from: url,
                dateRange: interval,
                options: options
            )
        }
    }

    private func youtubeItems(
        from url: URL,
        dateRange: DateInterval,
        options: SocialSourceOptions
    ) async throws -> [SocialSourceItem] {
        var entries: [YouTubeFeedEntry] = []

        if let channelID = options.youtubeChannelID,
           let rssEntries = try await youtubeRSSEntries(channelID: channelID) {
            entries.append(contentsOf: rssEntries
                .filter { dateRange.contains($0.publishedAt) }
                .filter { matchesTitleFilters($0.title, filters: options.youtubeTitleFilters) })
        }

        do {
            entries.append(contentsOf: try await youtubeChannelPageEntries(
                from: url,
                dateRange: dateRange,
                options: options
            ))
        } catch {
            guard entries.isEmpty else {
                return try await youtubeItems(from: deduplicatedYouTubeEntries(entries))
            }

            throw error
        }

        return try await youtubeItems(from: deduplicatedYouTubeEntries(entries))
    }

    private func youtubeRSSEntries(channelID: String) async throws -> [YouTubeFeedEntry]? {
        let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)")!
        let feedPage: SocialSourcePage

        do {
            feedPage = try await fetcher.fetch(SocialSourceRequest(
                url: feedURL,
                headers: youtubeRequestHeaders
            ))
        } catch {
            return nil
        }

        let allEntries = youTubeRSSFeedParser.entries(from: feedPage.html ?? feedPage.text)
        return allEntries.isEmpty ? nil : allEntries
    }

    private func youtubeChannelPageEntries(
        from url: URL,
        dateRange: DateInterval,
        options: SocialSourceOptions
    ) async throws -> [YouTubeFeedEntry] {
        let channelPageURL = youtubeVideosPageURL(from: url)
        let channelPage = try await fetcher.fetch(SocialSourceRequest(
            url: channelPageURL,
            headers: youtubeRequestHeaders
        ))
        let entries = youTubeChannelPageParser.entries(from: channelPage.html ?? channelPage.text)
            .filter { matchesTitleFilters($0.title, filters: options.youtubeTitleFilters) }

        var datedEntries: [YouTubeFeedEntry] = []

        for entry in entries {
            let videoURL = youtubeWatchURL(videoID: entry.videoID)
            let videoPage = try await fetcher.fetch(SocialSourceRequest(
                url: videoURL,
                headers: youtubeRequestHeaders
            ))
            guard let publishedAt = youTubeVideoDescriptionExtractor.publishedAt(
                from: videoPage.html ?? videoPage.text
            ),
                  dateRange.contains(publishedAt)
            else {
                continue
            }

            datedEntries.append(YouTubeFeedEntry(
                videoID: entry.videoID,
                title: entry.title,
                publishedAt: publishedAt
            ))
        }

        return datedEntries
    }

    private func deduplicatedYouTubeEntries(_ entries: [YouTubeFeedEntry]) -> [YouTubeFeedEntry] {
        var seen = Set<String>()
        var result: [YouTubeFeedEntry] = []

        for entry in entries {
            guard !seen.contains(entry.videoID) else {
                continue
            }

            seen.insert(entry.videoID)
            result.append(entry)
        }

        return result
    }

    private func youtubeItems(from entries: [YouTubeFeedEntry]) async throws -> [SocialSourceItem] {
        var items: [SocialSourceItem] = []

        for entry in entries {
            let videoURL = youtubeWatchURL(videoID: entry.videoID)
            let videoPage = try await fetcher.fetch(SocialSourceRequest(
                url: videoURL,
                headers: youtubeRequestHeaders
            ))
            let description = youTubeVideoDescriptionExtractor.description(from: videoPage.html ?? videoPage.text)
                ?? videoPage.text

            items.append(SocialSourceItem(
                sourceKind: "youtube_video",
                itemURL: videoURL,
                title: entry.title,
                publishedAt: entry.publishedAt,
                text: description
            ))
        }

        return items
    }

    private var youtubeRequestHeaders: [String: String] {
        [
            "Accept-Language": "en-US,en;q=0.9",
            "Cookie": "SOCS=CAI",
            "User-Agent": "Mozilla/5.0"
        ]
    }

    private func youtubeVideosPageURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        let path = components.percentEncodedPath
        if !path.hasSuffix("/videos") {
            components.percentEncodedPath = path.hasSuffix("/")
                ? "\(path)videos"
                : "\(path)/videos"
        }

        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "hl" }) {
            queryItems.append(URLQueryItem(name: "hl", value: "en"))
        }
        components.queryItems = queryItems

        return components.url ?? url
    }

    private func youtubeWatchURL(videoID: String) -> URL {
        URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
    }

    private func instagramItems(
        from url: URL,
        dateRange: DateInterval,
        options: SocialSourceOptions
    ) async throws -> [SocialSourceItem] {
        guard let username = instagramUsername(from: url) else {
            throw SocialSourceError.missingInstagramUsername(url)
        }

        var maxID: String?
        var pageCount = 0
        var items: [SocialSourceItem] = []

        while pageCount < options.instagramMaxPages {
            let feedURL = instagramFeedURL(username: username, maxID: maxID)
            let page = try await fetcher.fetch(SocialSourceRequest(
                url: feedURL,
                headers: [
                    "x-ig-app-id": "936619743392459",
                    "user-agent": "Mozilla/5.0"
                ]
            ))
            let feed = try instagramFeedParser.feed(from: page.html ?? page.text)
            var pageHasItemAtOrAfterRangeStart = false

            for item in feed.items {
                guard let takenAt = item.takenAt else {
                    continue
                }

                if takenAt >= dateRange.start {
                    pageHasItemAtOrAfterRangeStart = true
                }

                guard dateRange.contains(takenAt),
                      let caption = item.caption,
                      !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    continue
                }

                items.append(SocialSourceItem(
                    sourceKind: "instagram_post",
                    itemURL: item.postURL,
                    title: item.code.map { "Instagram post \($0)" },
                    publishedAt: takenAt,
                    text: caption
                ))
            }

            pageCount += 1

            guard feed.moreAvailable,
                  let nextMaxID = feed.nextMaxID,
                  pageHasItemAtOrAfterRangeStart
            else {
                break
            }

            maxID = nextMaxID
        }

        return items
    }

    private func matchesTitleFilters(_ title: String, filters: [String]) -> Bool {
        guard !filters.isEmpty else {
            return true
        }

        return filters.contains { filter in
            title.range(
                of: filter,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    private func dateInterval(from dateRange: [Date]) throws -> DateInterval {
        guard dateRange.count == 2 else {
            throw SocialSourceError.invalidDateRange(count: dateRange.count)
        }

        let start = min(dateRange[0], dateRange[1])
        let end = max(dateRange[0], dateRange[1])
        return DateInterval(start: start, end: end)
    }

    private func instagramUsername(from url: URL) -> String? {
        url.pathComponents.first {
            $0 != "/" && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func instagramFeedURL(username: String, maxID: String?) -> URL {
        var components = URLComponents(
            string: "https://www.instagram.com/api/v1/feed/user/\(username)/username/"
        )!
        var queryItems = [
            URLQueryItem(name: "count", value: "50")
        ]

        if let maxID {
            queryItems.append(URLQueryItem(name: "max_id", value: maxID))
        }

        components.queryItems = queryItems
        return components.url!
    }
}

public func getDescription(
    from url: URL,
    type: SocialSourceType
) async throws -> String {
    try await SocialSourceClient().getDescription(from: url, type: type)
}

public func getDescriptions(
    from url: URL,
    dateRange: [Date],
    type: SocialSourceType
) async throws -> [String] {
    try await SocialSourceClient().getDescriptions(
        from: url,
        dateRange: dateRange,
        type: type
    )
}

public struct YouTubeFeedEntry: Hashable, Sendable {
    public let videoID: String
    public let title: String
    public let publishedAt: Date

    public init(videoID: String, title: String, publishedAt: Date) {
        self.videoID = videoID
        self.title = title
        self.publishedAt = publishedAt
    }
}

public struct YouTubeChannelPageEntry: Hashable, Sendable {
    public let videoID: String
    public let title: String

    public init(videoID: String, title: String) {
        self.videoID = videoID
        self.title = title
    }
}

public struct YouTubeRSSFeedParser: Sendable {
    public init() {}

    public func entries(from xml: String) -> [YouTubeFeedEntry] {
        let publishedDateFormatter = ISO8601DateFormatter()
        publishedDateFormatter.formatOptions = [.withInternetDateTime]

        let entryXMLs = matches(
            in: xml,
            pattern: #"<entry>([\s\S]*?)</entry>"#
        )

        return entryXMLs.compactMap { entryXML -> YouTubeFeedEntry? in
            guard let videoID = firstMatch(in: entryXML, pattern: #"<yt:videoId>([^<]+)</yt:videoId>"#),
                  let title = firstMatch(in: entryXML, pattern: #"<title>([\s\S]*?)</title>"#),
                  let publishedText = firstMatch(in: entryXML, pattern: #"<published>([^<]+)</published>"#),
                  let publishedAt = publishedDateFormatter.date(from: publishedText)
            else {
                return nil
            }

            return YouTubeFeedEntry(
                videoID: decodeEntities(videoID),
                title: decodeEntities(title),
                publishedAt: publishedAt
            )
        }
    }

    private func matches(in value: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
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

    private func firstMatch(in value: String, pattern: String) -> String? {
        matches(in: value, pattern: pattern).first
    }

    private func decodeEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct YouTubeChannelPageParser: Sendable {
    public init() {}

    public func entries(from html: String) -> [YouTubeChannelPageEntry] {
        let pattern = #""watchEndpoint":\{"videoId":"([^"]+)"[\s\S]{0,4500}?"metadata":\{"lockupMetadataViewModel":\{"title":\{"content":"((?:\\.|[^"\\])*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var seen = Set<String>()

        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 2,
                  let videoIDRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html)
            else {
                return nil
            }

            let videoID = String(html[videoIDRange])
            guard !seen.contains(videoID) else {
                return nil
            }

            seen.insert(videoID)
            return YouTubeChannelPageEntry(
                videoID: videoID,
                title: decodeJSONString(String(html[titleRange]))
            )
        }
    }

    private func decodeJSONString(_ value: String) -> String {
        let jsonString = "\"\(value)\""
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? String
        else {
            return value
                .replacingOccurrences(of: #"\/"#, with: "/")
                .replacingOccurrences(of: #"\u0026"#, with: "&")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct YouTubeVideoDescriptionExtractor: Sendable {
    public init() {}

    public func description(from html: String) -> String? {
        guard let playerResponse = firstMatch(
            in: html,
            pattern: #"ytInitialPlayerResponse\s*=\s*(\{[\s\S]*?\})\s*;"#
        ),
              let data = playerResponse.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let videoDetails = json["videoDetails"] as? [String: Any],
              let description = videoDetails["shortDescription"] as? String
        else {
            return nil
        }

        return description
    }

    public func publishedAt(from html: String) -> Date? {
        let dateText = firstMatch(in: html, pattern: #""uploadDate":"([^"]+)""#)
            ?? firstMatch(in: html, pattern: #""publishDate":"([^"]+)""#)
            ?? firstMatch(in: html, pattern: #"datePublished"\s+content="([^"]+)""#)
        guard let dateText else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateText)
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

struct InstagramFeed: Sendable {
    let items: [InstagramFeedItem]
    let moreAvailable: Bool
    let nextMaxID: String?
}

struct InstagramFeedItem: Sendable {
    let code: String?
    let takenAt: Date?
    let caption: String?

    var postURL: URL? {
        guard let code else {
            return nil
        }

        return URL(string: "https://www.instagram.com/p/\(code)/")
    }
}

struct InstagramFeedParser: Sendable {
    func feed(from json: String) throws -> InstagramFeed {
        let response = try JSONDecoder().decode(
            InstagramFeedResponse.self,
            from: Data(json.utf8)
        )

        return InstagramFeed(
            items: response.items.map {
                InstagramFeedItem(
                    code: $0.code,
                    takenAt: $0.takenAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                    caption: $0.caption?.text
                )
            },
            moreAvailable: response.moreAvailable ?? false,
            nextMaxID: response.nextMaxID
        )
    }
}

private struct InstagramFeedResponse: Decodable {
    let items: [InstagramFeedItemResponse]
    let moreAvailable: Bool?
    let nextMaxID: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case moreAvailable = "more_available"
        case nextMaxID = "next_max_id"
    }
}

private struct InstagramFeedItemResponse: Decodable {
    let code: String?
    let takenAt: Int?
    let caption: InstagramCaptionResponse?

    private enum CodingKeys: String, CodingKey {
        case code
        case takenAt = "taken_at"
        case caption
    }
}

private struct InstagramCaptionResponse: Decodable {
    let text: String?
}
