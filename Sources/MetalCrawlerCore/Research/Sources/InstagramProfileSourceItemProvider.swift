import Foundation
import SocialSourceKit

struct InstagramProfileSourceItemProvider: Sendable {
    private let maxPages: Int

    init(maxPages: Int = 12) {
        self.maxPages = maxPages
    }

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
            type: .instagram,
            options: SocialSourceOptions(instagramMaxPages: maxPages)
        )

        return items.map { item in
            MonthlyMetalSourceItem(
                sourceName: descriptor.name,
                sourceKind: item.sourceKind,
                sourceURL: sourceURL,
                itemURL: item.itemURL,
                title: item.title,
                publishedAt: item.publishedAt,
                text: item.text
            )
        }
    }

    private static func monthDateRange(for month: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let interval = calendar.dateInterval(of: .month, for: month)!
        return [interval.start, interval.end]
    }
}
