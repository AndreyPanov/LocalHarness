import Foundation

struct MetalArchivesAdvancedAlbumSearchSource: Sendable {
    private let extractor: MetalArchivesAdvancedAlbumSearchExtractor
    private let pageSize: Int
    private let includedReleaseTypes: Set<String>

    init(
        extractor: MetalArchivesAdvancedAlbumSearchExtractor = MetalArchivesAdvancedAlbumSearchExtractor(),
        pageSize: Int = 200,
        includedReleaseTypes: Set<String> = ["full-length", "ep"]
    ) {
        self.extractor = extractor
        self.pageSize = pageSize
        self.includedReleaseTypes = includedReleaseTypes
    }

    func albums(
        for month: Date,
        context: ResearchContext
    ) async throws -> [MetalArchivesAdvancedAlbumSearchResult] {
        var albums: [MetalArchivesAdvancedAlbumSearchResult] = []
        var seen = Set<URL>()
        var start = 0

        while true {
            let response = try await searchPage(for: month, start: start, context: context)
            let pageAlbums = extractor.albums(from: response)
            let includedPageAlbums = pageAlbums.filter(isIncludedReleaseType)

            for album in includedPageAlbums where !seen.contains(album.albumURL) {
                seen.insert(album.albumURL)
                albums.append(album)
            }

            start += pageSize

            if start >= response.iTotalDisplayRecords || pageAlbums.isEmpty {
                break
            }
        }

        return albums
    }

    func albumURLs(for month: Date, context: ResearchContext) async throws -> [URL] {
        let albums = try await albums(for: month, context: context)
        return albums.map(\.albumURL)
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
            URLQueryItem(name: "releaseType[]", value: "1"),
            URLQueryItem(name: "releaseType[]", value: "5"),
            URLQueryItem(name: "iDisplayStart", value: "\(start)"),
            URLQueryItem(name: "iDisplayLength", value: "\(pageSize)")
        ]

        return urlComponents.url!
    }

    private func isIncludedReleaseType(_ album: MetalArchivesAdvancedAlbumSearchResult) -> Bool {
        includedReleaseTypes.contains(album.releaseType.lowercased())
    }
}
