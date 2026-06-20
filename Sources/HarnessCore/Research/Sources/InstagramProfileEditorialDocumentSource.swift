import Foundation

struct InstagramProfileEditorialDocumentSource: Sendable {
    private let feedParser: InstagramFeedParser
    private let maxPages: Int

    init(
        feedParser: InstagramFeedParser = InstagramFeedParser(),
        maxPages: Int = 12
    ) {
        self.feedParser = feedParser
        self.maxPages = maxPages
    }

    func documents(
        for month: Date,
        descriptor: EditorialSourceDescriptor,
        context: ResearchContext
    ) async throws -> [MonthlyMetalEditorialSourceDocument] {
        guard let username = descriptor.username else {
            return []
        }

        var maxID: String?
        var pageCount = 0
        var documents: [MonthlyMetalEditorialSourceDocument] = []
        let monthInterval = Self.monthInterval(for: month)

        while pageCount < maxPages {
            let feedURL = feedURL(username: username, maxID: maxID)
            let page = try await context.crawlClient.fetch(
                CrawlRequest(
                    url: feedURL,
                    source: ResearchSource(rawValue: "instagram_profile_feed"),
                    headers: [
                        "x-ig-app-id": "936619743392459",
                        "user-agent": "Mozilla/5.0"
                    ]
                )
            )
            let feed = try feedParser.feed(from: page.html ?? page.text)
            var pageHasItemAtOrAfterMonthStart = false

            for item in feed.items {
                guard let takenAt = item.takenAt else {
                    continue
                }

                if takenAt >= monthInterval.start {
                    pageHasItemAtOrAfterMonthStart = true
                }

                guard monthInterval.contains(takenAt),
                      let caption = item.caption,
                      !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    continue
                }

                documents.append(
                    MonthlyMetalEditorialSourceDocument(
                        sourceName: descriptor.name,
                        sourceKind: "instagram_post",
                        sourceURL: descriptor.sourceURL,
                        itemURL: item.postURL,
                        title: item.code.map { "Instagram post \($0)" },
                        publishedAt: takenAt,
                        text: caption
                    )
                )
            }

            pageCount += 1

            guard feed.moreAvailable,
                  let nextMaxID = feed.nextMaxID,
                  pageHasItemAtOrAfterMonthStart
            else {
                break
            }

            maxID = nextMaxID
        }

        return documents
    }

    private func feedURL(username: String, maxID: String?) -> URL {
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

    private static func monthInterval(for month: Date) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.dateInterval(of: .month, for: month)!
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
