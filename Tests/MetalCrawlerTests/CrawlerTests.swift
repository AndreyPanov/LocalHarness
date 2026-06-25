import Foundation
import Testing
@testable import MetalCrawlerCore

@Test func cachedCrawlClientWritesAndReadsCachedMetalArchivesPages() async throws {
    let cacheDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: cacheDirectory) }

    let page = try lampOfMurmuurPage()

    let wrapped = CountingCrawlClient(page: page)
    let client = CachedCrawlClient(wrapped: wrapped, cacheDirectory: cacheDirectory)
    let request = CrawlRequest(url: page.url, source: ResearchSource(rawValue: "metal_archives"))

    let first = try await client.fetch(request)
    let second = try await client.fetch(request)

    #expect(first.url == page.url)
    #expect(first.finalURL == page.finalURL)
    #expect(first.title == page.title)
    #expect(first.text == page.text)
    #expect(first.html == page.html)
    #expect(first.title == "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives")
    #expect(first.text.contains("Lamp of Murmuur"))
    #expect(first.text.contains("The Dreaming Prince in Ecstasy"))
    #expect(first.html?.contains(#"id="album_info""#) == true)

    #expect(second.url == page.url)
    #expect(second.finalURL == page.finalURL)
    #expect(second.title == page.title)
    #expect(second.text == page.text)
    #expect(second.html == page.html)
    #expect(await wrapped.fetchCount() == 1)
}

@Test func cachedCrawlClientUsesShortFileNamesForLongSearchURLs() async throws {
    let cacheDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: cacheDirectory) }

    let url = URL(string: "https://www.metal-archives.com/search/ajax-advanced/searching/albums/?releaseYearFrom=2026&releaseMonthFrom=06&releaseYearTo=2026&releaseMonthTo=06&iDisplayStart=0&iDisplayLength=200")!
    let page = CrawledPage(
        url: url,
        finalURL: url,
        title: nil,
        text: #"{"aaData":[]}"#,
        html: #"{"aaData":[]}"#
    )
    let wrapped = CountingCrawlClient(page: page)
    let client = CachedCrawlClient(wrapped: wrapped, cacheDirectory: cacheDirectory)
    let request = CrawlRequest(
        url: url,
        source: ResearchSource(rawValue: "metal_archives_advanced_album_search")
    )

    _ = try await client.fetch(request)
    _ = try await client.fetch(request)

    let cacheFileNames = try FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path)
    let cacheFileName = try #require(cacheFileNames.first)

    #expect(cacheFileNames.count == 1)
    #expect(cacheFileName.count < 255)
    #expect(await wrapped.fetchCount() == 1)
}

@Test func htmlTextExtractorReturnsTitleAndVisibleMetalArchivesText() throws {
    let html = try lampOfMurmuurHTML()

    #expect(HTMLTextExtractor.shared.title(from: html) == "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives")

    let text = HTMLTextExtractor.shared.visibleText(from: html)
    #expect(text.contains("Lamp of Murmuur"))
    #expect(text.contains("The Dreaming Prince in Ecstasy"))
    #expect(text.contains("Release date"))
    #expect(!text.contains("var URL_SITE"))
    #expect(!text.contains(".no-js"))
}

private actor CountingCrawlClient: CrawlClient {
    private let page: CrawledPage
    private var count = 0

    init(page: CrawledPage) {
        self.page = page
    }

    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        count += 1
        return page
    }

    func fetchCount() -> Int {
        count
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("metal-crawler-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
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
    let fixtureURL = try #require(Bundle.module.url(
        forResource: "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives",
        withExtension: "html",
        subdirectory: "Fixtures"
    ))

    return try String(contentsOf: fixtureURL, encoding: .utf8)
}
