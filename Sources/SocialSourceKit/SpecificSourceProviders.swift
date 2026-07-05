import Foundation

public struct BangerTVSourceProvider: SourceItemProviding {
    private let sourceProvider: any SocialDescriptionProviding

    public init(
        sourceProvider: any SocialDescriptionProviding = SocialSourceClient()
    ) {
        self.sourceProvider = sourceProvider
    }

    public func sourceItems(
        for month: Date,
        descriptor: SourceProviderDescriptor
    ) async throws -> [SourceProviderItem] {
        guard let sourceURL = descriptor.sourceURL else {
            return []
        }

        let items = try await sourceProvider.getDescriptionItems(
            from: sourceURL,
            dateRange: monthDateRange(for: month),
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
                SourceProviderItem(
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
}

public struct InstagramProfileSourceProvider: SourceItemProviding {
    private let sourceProvider: any SocialDescriptionProviding
    private let maxPages: Int

    public init(
        sourceProvider: any SocialDescriptionProviding = SocialSourceClient(),
        maxPages: Int = 12
    ) {
        self.sourceProvider = sourceProvider
        self.maxPages = maxPages
    }

    public func sourceItems(
        for month: Date,
        descriptor: SourceProviderDescriptor
    ) async throws -> [SourceProviderItem] {
        guard let sourceURL = descriptor.sourceURL else {
            return []
        }

        let items = try await sourceProvider.getDescriptionItems(
            from: sourceURL,
            dateRange: monthDateRange(for: month),
            type: .instagram,
            options: SocialSourceOptions(instagramMaxPages: maxPages)
        )

        return items.map { item in
            SourceProviderItem(
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
}

public struct SourceCandidateSignalDetector: SourceCandidateSignalFiltering {
    public static let shared = SourceCandidateSignalDetector()

    public init() {}

    public func shouldExtractCandidates(from item: SourceProviderItem) -> Bool {
        shouldExtractCandidates(
            sourceKind: item.sourceKind,
            text: item.text
        )
    }

    public func shouldExtractCandidates(sourceKind: String, text: String) -> Bool {
        guard sourceKind == "instagram_post" else {
            return true
        }

        let normalizedText = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let albumSignals = [
            "new arrival",
            "new arrivals",
            "vinyl",
            " lp",
            " cd",
            "cassette",
            "tape",
            "full length",
            "full-length",
            "album",
            "demo",
            "ep",
            "black metal",
            "death metal",
            "doom metal",
            "heavy metal",
            "thrash metal"
        ]

        return albumSignals.contains { normalizedText.contains($0) }
    }
}

private func monthDateRange(for month: Date) -> [Date] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let interval = calendar.dateInterval(of: .month, for: month)!
    return [interval.start, interval.end]
}
