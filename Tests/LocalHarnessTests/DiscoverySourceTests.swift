import Foundation
import Testing
@testable import HarnessCore

@Test func metalArchivesDiscoveryFiltersByRequestedMonth() async throws {
    let mayURL = URL(string: "https://example.com/may")!
    let juneURL = URL(string: "https://example.com/june")!

    let pages = [
        mayURL: metalArchivesPage(
            url: mayURL,
            band: "May Band",
            album: "May Album",
            releaseDate: "May 10th, 2026"
        ),
        juneURL: metalArchivesPage(
            url: juneURL,
            band: "June Band",
            album: "June Album",
            releaseDate: "June 1st, 2026"
        )
    ]

    let context = ResearchContext(
        month: MonthlyMetalDateFormatter.shared.parse("2026-05-01")!,
        runID: RunID(),
        crawlClient: DictionaryCrawlClient(pages: pages),
        llmFallback: FailingLLMFallback(),
        runsDirectory: FileManager.default.temporaryDirectory,
        knowledgeDirectory: FileManager.default.temporaryDirectory
    )

    let source = MetalArchivesAlbumDiscoverySource(albumURLs: [mayURL, juneURL])
    let candidates = try await source.discover(month: context.month, context: context)

    #expect(candidates.count == 1)
    #expect(candidates.first?.bandName == "May Band")
    #expect(candidates.first?.albumTitle == "May Album")
}

private func metalArchivesPage(
    url: URL,
    band: String,
    album: String,
    releaseDate: String
) -> CrawledPage {
    let html = """
    <html>
      <head>
        <title>\(band) - \(album) - Encyclopaedia Metallum</title>
      </head>
      <body>
        <h1 class="band_name"><a>\(band)</a></h1>
        <h1 class="album_name"><a>\(album)</a></h1>
        <dl>
          <dt>Type:</dt>
          <dd>Full-length</dd>
          <dt>Release date:</dt>
          <dd>\(releaseDate)</dd>
        </dl>
      </body>
    </html>
    """

    return CrawledPage(
        url: url,
        finalURL: url,
        title: "\(band) - \(album) - Encyclopaedia Metallum",
        text: HTMLTextExtractor.shared.visibleText(from: html),
        html: html
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
