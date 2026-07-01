import Foundation
import SocialSourceKit

struct BangerTVSourceItemProvider: Sendable {
    func sourceItems(
        for month: Date,
        descriptor: MonthlyMetalSourceDescriptor,
        context: ResearchContext
    ) async throws -> [MonthlyMetalSourceItem] {
        guard let sourceURL = descriptor.sourceURL else {
            return []
        }

        let client = SocialSourceClient(
            fetcher: CrawlClientSocialSourceFetcher(crawlClient: context.crawlClient)
        )
        let items = try await client.getDescriptionItems(
            from: sourceURL,
            dateRange: Self.monthDateRange(for: month),
            type: .youtube,
            options: SocialSourceOptions(
                youtubeChannelID: descriptor.channelID,
                youtubeTitleFilters: [
                    "METAL MONTHLY",
                    "Metal Album Reviews"
                ]
            )
        )

        return items
            .filter(isRelevant)
            .map { item in
                MonthlyMetalSourceItem(
                    sourceName: descriptor.name,
                    sourceKind: sourceKind(for: item),
                    sourceURL: sourceURL,
                    itemURL: item.itemURL,
                    title: item.title,
                    publishedAt: item.publishedAt,
                    text: item.text
                )
            }
    }

    private func isRelevant(_ item: SocialSourceItem) -> Bool {
        isMonthlyVideo(item) || isAlbumReviewVideo(item)
    }

    private func isMonthlyVideo(_ item: SocialSourceItem) -> Bool {
        item.title?.range(
            of: "METAL MONTHLY",
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }

    private func isAlbumReviewVideo(_ item: SocialSourceItem) -> Bool {
        item.title?.range(
            of: "Metal Album Reviews",
            options: [.caseInsensitive, .diacriticInsensitive]
        ) != nil
    }

    private func sourceKind(for item: SocialSourceItem) -> String {
        isAlbumReviewVideo(item) ? "youtube_album_review" : "youtube_monthly"
    }

    private static func monthDateRange(for month: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let interval = calendar.dateInterval(of: .month, for: month)!
        return [interval.start, interval.end]
    }
}
