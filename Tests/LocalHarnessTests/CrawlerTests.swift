import Foundation
import Testing
@testable import HarnessCore

@Test func cachedCrawlClientWritesAndReadsCachedPages() async throws {
    let cacheDirectory = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: cacheDirectory) }

    let url = URL(string: "https://example.com/releases")!
    let page = CrawledPage(
        url: url,
        finalURL: url,
        title: "Example Releases",
        text: "Visible release text",
        html: "<html><head><title>Example Releases</title></head><body>Visible release text</body></html>"
    )

    let wrapped = CountingCrawlClient(page: page)
    let client = CachedCrawlClient(wrapped: wrapped, cacheDirectory: cacheDirectory)
    let request = CrawlRequest(url: url, source: ResearchSource(rawValue: "test"))

    let first = try await client.fetch(request)
    let second = try await client.fetch(request)

    #expect(first.url == page.url)
    #expect(first.finalURL == page.finalURL)
    #expect(first.title == page.title)
    #expect(first.text == page.text)
    #expect(first.html == page.html)

    #expect(second.url == page.url)
    #expect(second.finalURL == page.finalURL)
    #expect(second.title == page.title)
    #expect(second.text == page.text)
    #expect(second.html == page.html)
    #expect(await wrapped.fetchCount() == 1)
}

@Test func htmlTextExtractorReturnsTitleAndVisibleText() {
    let html = """
    <html>
      <head>
        <title>Monthly Metal</title>
        <style>.hidden { display: none; }</style>
      </head>
      <body>
        <h1>May Releases</h1>
        <script>window.secret = "ignored";</script>
        <p>Death metal from Finland.</p>
      </body>
    </html>
    """

    #expect(HTMLTextExtractor.title(from: html) == "Monthly Metal")

    let text = HTMLTextExtractor.visibleText(from: html)
    #expect(text.contains("May Releases"))
    #expect(text.contains("Death metal from Finland."))
    #expect(!text.contains("window.secret"))
    #expect(!text.contains("display: none"))
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
        .appendingPathComponent("local-harness-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
