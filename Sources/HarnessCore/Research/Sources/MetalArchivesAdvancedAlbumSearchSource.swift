import Foundation

struct MetalArchivesAdvancedAlbumSearchSource: Sendable {
    private let extractor: MetalArchivesAdvancedAlbumSearchExtractor
    private let pageSize: Int

    init(
        extractor: MetalArchivesAdvancedAlbumSearchExtractor = MetalArchivesAdvancedAlbumSearchExtractor(),
        pageSize: Int = 200
    ) {
        self.extractor = extractor
        self.pageSize = pageSize
    }

    func albumURLs(for month: Date, context: ResearchContext) async throws -> [URL] {
        var urls: [URL] = []
        var seen = Set<URL>()
        var start = 0

        while true {
            let response = try await searchPage(for: month, start: start, context: context)
            let pageURLs = extractor.albumURLs(from: response)

            for url in pageURLs where !seen.contains(url) {
                seen.insert(url)
                urls.append(url)
            }

            start += pageSize

            if start >= response.iTotalDisplayRecords || pageURLs.isEmpty {
                break
            }
        }

        return urls
    }

    private func searchPage(
        for month: Date,
        start: Int,
        context: ResearchContext
    ) async throws -> MetalArchivesAdvancedAlbumSearchResponse {
        let url = searchURL(for: month, start: start, pageSize: pageSize)
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
        return response
    }

    func searchURL(for month: Date) -> URL {
        searchURL(for: month, start: 0, pageSize: pageSize)
    }

    func searchURL(for month: Date, start: Int, pageSize: Int) -> URL {
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
            URLQueryItem(name: "releaseMonthTo", value: String(format: "%02d", monthNumber)),
            URLQueryItem(name: "iDisplayStart", value: "\(start)"),
            URLQueryItem(name: "iDisplayLength", value: "\(pageSize)")
        ]

        return urlComponents.url!
    }
}
