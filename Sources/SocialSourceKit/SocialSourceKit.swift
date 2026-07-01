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
    private let youTubeVideoDescriptionExtractor: YouTubeVideoDescriptionExtractor
    private let instagramFeedParser: InstagramFeedParser

    public init(
        fetcher: any SocialSourceFetching = URLSessionSocialSourceFetcher(),
        youTubeRSSFeedParser: YouTubeRSSFeedParser = YouTubeRSSFeedParser(),
        youTubeVideoDescriptionExtractor: YouTubeVideoDescriptionExtractor = YouTubeVideoDescriptionExtractor()
    ) {
        self.fetcher = fetcher
        self.youTubeRSSFeedParser = youTubeRSSFeedParser
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
        guard let channelID = options.youtubeChannelID else {
            throw SocialSourceError.missingYouTubeChannelID(url)
        }

        let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)")!
        let feedPage = try await fetcher.fetch(SocialSourceRequest(url: feedURL))
        let entries = youTubeRSSFeedParser.entries(from: feedPage.html ?? feedPage.text)
            .filter { dateRange.contains($0.publishedAt) }
            .filter { matchesTitleFilters($0.title, filters: options.youtubeTitleFilters) }

        var items: [SocialSourceItem] = []

        for entry in entries {
            let videoURL = URL(string: "https://www.youtube.com/watch?v=\(entry.videoID)")!
            let videoPage = try await fetcher.fetch(SocialSourceRequest(url: videoURL))
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
