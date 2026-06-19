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
    let albums = MetalArchivesAdvancedAlbumSearchExtractor().albums(from: response)

    #expect(urls == [
        URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!
    ])
    #expect(albums.first?.bandName == "Lamp of Murmuur")
    #expect(albums.first?.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(albums.first?.releaseType == "Full-length")
    #expect(albums.first?.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2025-11-14")
}

@Test func metalArchivesAdvancedSearchSourcePaginatesFiltersAndDeduplicatesAlbumURLs() async throws {
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2025-11-01"))
    let searchSource = MetalArchivesAdvancedAlbumSearchSource(pageSize: 2)
    let firstSearchURL = searchSource.searchURL(for: month, start: 0, pageSize: 2)
    let secondSearchURL = searchSource.searchURL(for: month, start: 2, pageSize: 2)
    let firstSearchQueryItems = try #require(URLComponents(
        url: firstSearchURL,
        resolvingAgainstBaseURL: false
    )?.queryItems)

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

    #expect(firstSearchQueryItems.filter { $0.name == "releaseType[]" }.map(\.value) == ["1", "5"])
    #expect(urls == [
        URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!,
        URL(string: "https://www.metal-archives.com/albums/Dzyan/Dzyan/1386184")!
    ])
}

@Test func editorialReleaseParserExtractsBangerTVDescriptionBlocks() throws {
    let description = try fixtureString(
        named: "bangertv-metal-monthly-june-2026",
        fileExtension: "txt"
    )
    let descriptor = EditorialReleaseSourceDescriptor(
        name: "BangerTV Metal Monthly June 2026",
        kind: "youtube_description",
        sourceURL: URL(string: "https://www.youtube.com/watch?v=Punc3i5Su30")!,
        file: "bangertv-metal-monthly-june-2026.txt"
    )

    let seeds = EditorialReleaseDescriptionParser().seeds(
        from: description,
        descriptor: descriptor
    )
    let first = try #require(seeds.first)
    let last = try #require(seeds.last)

    #expect(seeds.count == 5)
    #expect(first.bandName == "Astriferous")
    #expect(first.albumTitle == "Atavistic Unraveling")
    #expect(first.labelName == "Me Saco un Ojo/Pulverised")
    #expect(first.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2026-06-26")
    #expect(first.source.name == "BangerTV Metal Monthly June 2026")
    #expect(first.source.kind == "youtube_description")
    #expect(first.source.rank == 1)
    #expect(first.source.sourceURL == URL(string: "https://www.youtube.com/watch?v=Punc3i5Su30")!)
    #expect(first.source.itemURL == URL(string: "https://mesacounojo.bandcamp.com/album/atavistic-unraveling")!)
    #expect(last.bandName == "Iron Kobra")
    #expect(last.albumTitle == "Eternal Dagger")
}

@Test func monthlyMetalScoutBuildsCandidatePoolWithEditorialSources() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    let runsDirectory = temporaryDirectory.appendingPathComponent("runs", isDirectory: true)
    let knowledgeDirectory = temporaryDirectory.appendingPathComponent("knowledge", isDirectory: true)
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2025-11-01"))
    let searchURL = MetalArchivesAdvancedAlbumSearchSource().searchURL(for: month)
    let searchPage = try jsonPage(
        url: searchURL,
        fixtureName: "metal-archives-advanced-album-search-2025-11"
    )

    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try writeEditorialSource(
        month: "2025-11",
        knowledgeDirectory: knowledgeDirectory,
        manifest: """
        {
          "sources": [
            {
              "name": "Example monthly top albums",
              "kind": "ranked_list",
              "url": "https://example.com/monthly-top-albums",
              "file": "top-albums.txt"
            }
          ]
        }
        """,
        files: [
            "top-albums.txt": """
            1. Lamp of Murmuur - The Dreaming Prince in Ecstasy https://example.com/lamp-review
            2. Editorial Only - Hidden Demo https://example.com/hidden-demo
            """
        ]
    )

    let scout = MonthlyMetalScout(
        runsDirectory: runsDirectory,
        knowledgeDirectory: knowledgeDirectory,
        runIDProvider: { RunID("test-monthly-metal-scout") },
        crawlClientFactory: { _ in DictionaryCrawlClient(pages: [searchURL: searchPage]) }
    )

    let result = try await scout.listCandidates(month: "2025-11")
    let lamp = try #require(result.candidates.first {
        $0.bandName == "Lamp of Murmuur"
    })
    let editorialOnly = try #require(result.candidates.first {
        $0.bandName == "Editorial Only"
    })

    #expect(result.runID == RunID("test-monthly-metal-scout"))
    #expect(FileManager.default.fileExists(atPath: result.runDirectory.path))
    #expect(FileManager.default.fileExists(atPath: result.candidateArtifactURL.path))
    #expect(result.candidates.count == 2)
    #expect(lamp.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(lamp.releaseType == "Full-length")
    #expect(lamp.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2025-11-14")
    #expect(lamp.metalArchivesURL == URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!)
    #expect(lamp.sources.map(\.name) == [
        "Metal Archives monthly search",
        "Example monthly top albums"
    ])
    #expect(lamp.sources.last?.itemURL == URL(string: "https://example.com/lamp-review")!)
    #expect(editorialOnly.albumTitle == "Hidden Demo")
    #expect(editorialOnly.releaseType == nil)
    #expect(editorialOnly.metalArchivesURL == nil)
    #expect(editorialOnly.sources.first?.rank == 2)
}

@Test func monthlyMetalScoutListsCatalogCandidatesWithoutFetchingAlbumPages() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    let runsDirectory = temporaryDirectory.appendingPathComponent("runs", isDirectory: true)
    let knowledgeDirectory = temporaryDirectory.appendingPathComponent("knowledge", isDirectory: true)
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2025-11-01"))
    let searchURL = MetalArchivesAdvancedAlbumSearchSource().searchURL(for: month)
    let searchPage = try jsonPage(
        url: searchURL,
        fixtureName: "metal-archives-advanced-album-search-2025-11"
    )

    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let scout = MonthlyMetalScout(
        runsDirectory: runsDirectory,
        knowledgeDirectory: knowledgeDirectory,
        runIDProvider: { RunID("test-monthly-metal-list") },
        crawlClientFactory: { _ in DictionaryCrawlClient(pages: [searchURL: searchPage]) }
    )

    let result = try await scout.listCandidates(month: "2025-11")

    #expect(result.runID == RunID("test-monthly-metal-list"))
    #expect(FileManager.default.fileExists(atPath: result.candidateArtifactURL.path))
    #expect(result.candidates.count == 1)
    #expect(result.candidates.first?.bandName == "Lamp of Murmuur")
    #expect(result.candidates.first?.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(result.candidates.first?.releaseType == "Full-length")
    #expect(result.candidates.first?.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2025-11-14")
    #expect(result.candidates.first?.metalArchivesURL == URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!)
    #expect(result.candidates.first?.sources.first?.name == "Metal Archives monthly search")
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

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("local-harness-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeEditorialSource(
    month: String,
    knowledgeDirectory: URL,
    manifest: String,
    files: [String: String]
) throws {
    let sourceDirectory = knowledgeDirectory
        .appendingPathComponent("editorial-sources", isDirectory: true)
        .appendingPathComponent(month, isDirectory: true)

    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    try manifest.write(
        to: sourceDirectory.appendingPathComponent("sources.json", isDirectory: false),
        atomically: true,
        encoding: .utf8
    )

    for (fileName, contents) in files {
        try contents.write(
            to: sourceDirectory.appendingPathComponent(fileName, isDirectory: false),
            atomically: true,
            encoding: .utf8
        )
    }
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
