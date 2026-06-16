import Foundation
import Testing
@testable import HarnessCore

@Test func metalArchivesAdvancedSearchExtractorFindsAlbumURLs() throws {
    let searchJSON = try fixtureString(
        named: "metal-archives-advanced-album-search-2025-11",
        fileExtension: "json"
    )
    let response = try JSONDecoder().decode(
        MetalArchivesAdvancedAlbumSearchResponse.self,
        from: Data(searchJSON.utf8)
    )

    let urls = MetalArchivesAdvancedAlbumSearchExtractor().albumURLs(from: response)

    #expect(urls == [
        URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!
    ])
}

@Test func metalArchivesAdvancedSearchSourcePaginatesAndDeduplicatesAlbumURLs() async throws {
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2025-11-01"))
    let searchSource = MetalArchivesAdvancedAlbumSearchSource(pageSize: 2)
    let firstSearchURL = searchSource.searchURL(for: month, start: 0, pageSize: 2)
    let secondSearchURL = searchSource.searchURL(for: month, start: 2, pageSize: 2)

    let context = ResearchContext(
        month: month,
        runID: RunID(),
        crawlClient: DictionaryCrawlClient(pages: [
            firstSearchURL: try jsonPage(
                url: firstSearchURL,
                fixtureName: "metal-archives-advanced-album-search-2025-11-page-1"
            ),
            secondSearchURL: try jsonPage(
                url: secondSearchURL,
                fixtureName: "metal-archives-advanced-album-search-2025-11-page-2"
            )
        ]),
        llmFallback: FailingLLMFallback(),
        runsDirectory: FileManager.default.temporaryDirectory,
        knowledgeDirectory: FileManager.default.temporaryDirectory
    )

    let urls = try await searchSource.albumURLs(for: month, context: context)

    #expect(urls == [
        URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!,
        URL(string: "https://www.metal-archives.com/albums/Abbashaitan/Sorceritual_%26_Rites_of_the_Unlight/1393271")!
    ])
}

@Test func metalArchivesMonthlyDiscoveryFindsAlbumFromAdvancedSearch() async throws {
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2025-11-01"))
    let searchSource = MetalArchivesAdvancedAlbumSearchSource()
    let searchURL = searchSource.searchURL(for: month)
    let albumPage = try lampOfMurmuurPage()
    let searchJSON = try fixtureString(
        named: "metal-archives-advanced-album-search-2025-11",
        fileExtension: "json"
    )

    let searchPage = CrawledPage(
        url: searchURL,
        finalURL: searchURL,
        title: nil,
        text: searchJSON,
        html: searchJSON
    )

    let context = ResearchContext(
        month: month,
        runID: RunID(),
        crawlClient: DictionaryCrawlClient(pages: [
            searchURL: searchPage,
            albumPage.url: albumPage
        ]),
        llmFallback: FailingLLMFallback(),
        runsDirectory: FileManager.default.temporaryDirectory,
        knowledgeDirectory: FileManager.default.temporaryDirectory
    )

    let source = MetalArchivesMonthlyReleaseDiscoverySource(searchSource: searchSource)
    let candidates = try await source.discover(month: month, context: context)

    #expect(candidates.count == 1)
    #expect(candidates.first?.bandName == "Lamp of Murmuur")
    #expect(candidates.first?.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(candidates.first?.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2025-11-14")
    #expect(candidates.first?.sources.first?.name == "metal_archives")
    #expect(candidates.first?.sources.first?.url == albumPage.finalURL)
}

@Test func metalArchivesDiscoveryReturnsRealAlbumForRequestedMonth() async throws {
    let page = try lampOfMurmuurPage()

    let context = ResearchContext(
        month: try #require(MonthlyMetalDateFormatter.shared.parse("2025-11-01")),
        runID: RunID(),
        crawlClient: DictionaryCrawlClient(pages: [page.url: page]),
        llmFallback: FailingLLMFallback(),
        runsDirectory: FileManager.default.temporaryDirectory,
        knowledgeDirectory: FileManager.default.temporaryDirectory
    )

    let source = MetalArchivesAlbumDiscoverySource(albumURLs: [page.url])
    let candidates = try await source.discover(month: context.month, context: context)

    #expect(candidates.count == 1)
    #expect(candidates.first?.bandName == "Lamp of Murmuur")
    #expect(candidates.first?.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(candidates.first?.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2025-11-14")
    #expect(candidates.first?.sources.first?.name == "metal_archives")
    #expect(candidates.first?.sources.first?.url == page.finalURL)
}

@Test func metalArchivesDiscoveryFiltersRealAlbumOutsideRequestedMonth() async throws {
    let page = try lampOfMurmuurPage()

    let context = ResearchContext(
        month: try #require(MonthlyMetalDateFormatter.shared.parse("2025-12-01")),
        runID: RunID(),
        crawlClient: DictionaryCrawlClient(pages: [page.url: page]),
        llmFallback: FailingLLMFallback(),
        runsDirectory: FileManager.default.temporaryDirectory,
        knowledgeDirectory: FileManager.default.temporaryDirectory
    )

    let source = MetalArchivesAlbumDiscoverySource(albumURLs: [page.url])
    let candidates = try await source.discover(month: context.month, context: context)

    #expect(candidates.isEmpty)
}

private func lampOfMurmuurPage() throws -> CrawledPage {
    let url = URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!
    let html = try lampOfMurmuurHTML()

    return CrawledPage(
        url: url,
        finalURL: url,
        title: HTMLTextExtractor.shared.title(from: html),
        text: HTMLTextExtractor.shared.visibleText(from: html),
        html: html
    )
}

private func lampOfMurmuurHTML() throws -> String {
    try fixtureString(
        named: "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives",
        fileExtension: "html"
    )
}

private func fixtureString(named name: String, fileExtension: String) throws -> String {
    let fixtureURL = try #require(Bundle.module.url(
        forResource: name,
        withExtension: fileExtension,
        subdirectory: "Fixtures"
    ))

    return try String(contentsOf: fixtureURL, encoding: .utf8)
}

private func jsonPage(url: URL, fixtureName: String) throws -> CrawledPage {
    let json = try fixtureString(named: fixtureName, fileExtension: "json")

    return CrawledPage(
        url: url,
        finalURL: url,
        title: nil,
        text: json,
        html: json
    )
}

private struct DictionaryCrawlClient: CrawlClient {
    let pages: [URL: CrawledPage]

    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        guard let page = pages[request.url] else {
            throw HarnessError.invalidCrawlResponse(request.url.absoluteString)
        }

        return page
    }
}

private struct FailingLLMFallback: LLMExtractionFallback {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate {
        throw HarnessError.invalidAgentAction("LLM fallback should not be used in this test.")
    }

    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft {
        throw HarnessError.invalidAgentAction("LLM fallback should not be used in this test.")
    }
}
