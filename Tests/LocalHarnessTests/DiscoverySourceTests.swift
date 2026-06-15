import Foundation
import Testing
@testable import HarnessCore

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
    let fixtureURL = try #require(Bundle.module.url(
        forResource: "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives",
        withExtension: "html",
        subdirectory: "Fixtures"
    ))

    return try String(contentsOf: fixtureURL, encoding: .utf8)
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
