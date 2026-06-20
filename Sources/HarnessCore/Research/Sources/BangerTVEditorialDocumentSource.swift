import Foundation

struct BangerTVEditorialDocumentSource: Sendable {
    private let feedParser: YouTubeRSSFeedParser
    private let videoDescriptionExtractor: YouTubeVideoDescriptionExtractor

    init(
        feedParser: YouTubeRSSFeedParser = YouTubeRSSFeedParser(),
        videoDescriptionExtractor: YouTubeVideoDescriptionExtractor = YouTubeVideoDescriptionExtractor()
    ) {
        self.feedParser = feedParser
        self.videoDescriptionExtractor = videoDescriptionExtractor
    }

    func documents(
        for month: Date,
        descriptor: EditorialSourceDescriptor,
        context: ResearchContext
    ) async throws -> [MonthlyMetalEditorialSourceDocument] {
        guard let channelID = descriptor.channelID else {
            return []
        }

        let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)")!
        let feedPage = try await context.crawlClient.fetch(
            CrawlRequest(
                url: feedURL,
                source: ResearchSource(rawValue: "youtube_channel_rss")
            )
        )
        let entries = feedParser.entries(from: feedPage.html ?? feedPage.text)
            .filter { isRelevant($0, for: month) }

        var documents: [MonthlyMetalEditorialSourceDocument] = []

        for entry in entries {
            let videoURL = URL(string: "https://www.youtube.com/watch?v=\(entry.videoID)")!
            let videoPage = try await context.crawlClient.fetch(
                CrawlRequest(
                    url: videoURL,
                    source: ResearchSource(rawValue: "youtube_video")
                )
            )
            let description = videoDescriptionExtractor.description(from: videoPage.html ?? videoPage.text)
                ?? videoPage.text

            documents.append(
                MonthlyMetalEditorialSourceDocument(
                    sourceName: descriptor.name,
                    sourceKind: sourceKind(for: entry),
                    sourceURL: descriptor.sourceURL,
                    itemURL: videoURL,
                    title: entry.title,
                    publishedAt: entry.publishedAt,
                    text: description
                )
            )
        }

        return documents
    }

    private func isRelevant(_ entry: YouTubeFeedEntry, for month: Date) -> Bool {
        guard Calendar.monthUTC(entry.publishedAt) == Calendar.monthUTC(month) else {
            return false
        }

        return isMonthlyVideo(entry, for: month) || isAlbumReviewVideo(entry)
    }

    private func isMonthlyVideo(_ entry: YouTubeFeedEntry, for month: Date) -> Bool {
        let components = Calendar.monthUTC(month)
        let monthName = Self.monthName(for: components.month!)
        let title = entry.title.uppercased()

        return title.contains("METAL MONTHLY")
            && title.contains(monthName.uppercased())
            && title.contains("\(components.year!)")
    }

    private func isAlbumReviewVideo(_ entry: YouTubeFeedEntry) -> Bool {
        entry.title.range(
            of: "Metal Album Reviews",
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }

    private func sourceKind(for entry: YouTubeFeedEntry) -> String {
        isAlbumReviewVideo(entry) ? "youtube_album_review" : "youtube_monthly"
    }

    private static func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.monthSymbols[month - 1]
    }
}

struct YouTubeFeedEntry: Hashable, Sendable {
    let videoID: String
    let title: String
    let publishedAt: Date
}

struct YouTubeRSSFeedParser: Sendable {
    func entries(from xml: String) -> [YouTubeFeedEntry] {
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

struct YouTubeVideoDescriptionExtractor: Sendable {
    func description(from html: String) -> String? {
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
