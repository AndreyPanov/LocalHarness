import Foundation

struct MetalArchivesAdvancedAlbumSearchSource: Sendable {
    private let extractor = MetalArchivesAdvancedAlbumSearchExtractor()

    func albumURLs(for month: Date, context: ResearchContext) async throws -> [URL] {
        let url = searchURL(for: month)
        let page = try await context.crawlClient.fetch(
            CrawlRequest(
                url: url,
                source: ResearchSource(rawValue: "metal_archives_advanced_album_search")
            )
        )

        let json = page.html ?? page.text
        let response = try JSONDecoder().decode(
            MetalArchivesAdvancedAlbumSearchResponse.self,
            from: Data(json.utf8)
        )

        return extractor.albumURLs(from: response)
    }

    func searchURL(for month: Date) -> URL {
        let components = Calendar.monthUTC(month)
        let year = components.year!
        let monthNumber = components.month!

        var urlComponents = URLComponents(
            string: "https://www.metal-archives.com/search/ajax-advanced/searching/albums/"
        )!

        urlComponents.queryItems = [
            URLQueryItem(name: "releaseYearFrom", value: "\(year)"),
            URLQueryItem(name: "releaseMonthFrom", value: String(format: "%02d", monthNumber)),
            URLQueryItem(name: "releaseYearTo", value: "\(year)"),
            URLQueryItem(name: "releaseMonthTo", value: String(format: "%02d", monthNumber))
        ]

        return urlComponents.url!
    }
}
