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

@Test func bangerTVRSSParserFindsMonthlyAndReviewVideos() throws {
    let xml = """
    <feed>
      <entry>
        <yt:videoId>DV-Z4kzZMfM</yt:videoId>
        <title>KHEMMIS  Khemmis | BangerTV Metal Album Reviews</title>
        <published>2026-06-19T19:22:02+00:00</published>
      </entry>
      <entry>
        <yt:videoId>Punc3i5Su30</yt:videoId>
        <title>METAL MONTHLY JUNE 2026 | Astriferous, Speedslut, Inherits the Void, Nuclear Tomb, Iron Kobra</title>
        <published>2026-06-03T15:19:20+00:00</published>
      </entry>
    </feed>
    """

    let entries = YouTubeRSSFeedParser().entries(from: xml)

    #expect(entries.map(\.videoID) == ["DV-Z4kzZMfM", "Punc3i5Su30"])
    #expect(entries.first?.title == "KHEMMIS  Khemmis | BangerTV Metal Album Reviews")
    #expect(entries.first.map { MonthlyMetalDateFormatter.shared.format($0.publishedAt) } == "2026-06-19")
}

@Test func bangerTVDocumentSourceKeepsFullVideoDescription() async throws {
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2026-06-01"))
    let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=test-channel")!
    let videoURL = URL(string: "https://www.youtube.com/watch?v=DV-Z4kzZMfM")!
    let feedXML = """
    <feed>
      <entry>
        <yt:videoId>DV-Z4kzZMfM</yt:videoId>
        <title>KHEMMIS  Khemmis | BangerTV Metal Album Reviews</title>
        <published>2026-06-19T19:22:02+00:00</published>
      </entry>
      <entry>
        <yt:videoId>short-video</yt:videoId>
        <title>Who does not love a mosh pit?</title>
        <published>2026-06-12T18:50:29+00:00</published>
      </entry>
    </feed>
    """
    let videoHTML = #"""
    <script>
    var ytInitialPlayerResponse = {"videoDetails":{"shortDescription":"Blayne reviews the new self titled album by doom legends Khemmis\n\nShout Outs\nMork - Monolitt - June 19th, 2026 - Peaceville Records"}};
    </script>
    """#
    let context = ResearchContext(
        month: month,
        runID: RunID(),
        crawlClient: DictionaryCrawlClient(pages: [
            feedURL: CrawledPage(url: feedURL, finalURL: feedURL, title: nil, text: feedXML, html: feedXML),
            videoURL: CrawledPage(url: videoURL, finalURL: videoURL, title: nil, text: videoHTML, html: videoHTML)
        ]),
        llmFallback: FailingLLMFallback(),
        runsDirectory: FileManager.default.temporaryDirectory,
        knowledgeDirectory: FileManager.default.temporaryDirectory
    )
    let descriptor = EditorialSourceDescriptor(
        name: "BangerTV",
        kind: "youtube_channel",
        sourceURL: URL(string: "https://www.youtube.com/@BangerTV")!,
        channelID: "test-channel"
    )

    let documents = try await BangerTVEditorialDocumentSource().documents(
        for: month,
        descriptor: descriptor,
        context: context
    )
    let document = try #require(documents.first)

    #expect(documents.count == 1)
    #expect(document.sourceName == "BangerTV")
    #expect(document.sourceKind == "youtube_album_review")
    #expect(document.sourceURL == URL(string: "https://www.youtube.com/@BangerTV")!)
    #expect(document.itemURL == videoURL)
    #expect(document.title == "KHEMMIS  Khemmis | BangerTV Metal Album Reviews")
    #expect(document.publishedAt.map(MonthlyMetalDateFormatter.shared.format) == "2026-06-19")
    #expect(document.text.contains("Mork - Monolitt - June 19th, 2026 - Peaceville Records"))
}

@Test func instagramDocumentSourceKeepsFullPostCaptions() async throws {
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2026-06-01"))
    let feedURL = URL(string: "https://www.instagram.com/api/v1/feed/user/infidelamsterdam/username/?count=50")!
    let json = """
    {
      "items": [
        {
          "code": "DZK_hBVsGaZ",
          "taken_at": 1780574400,
          "caption": {
            "text": "New arrivals!\\n\\nWalg: Walg l\\n( 12” green vinyl, full length, reissue by Zwaertgevegt )\\nWalg: lV\\n( Cd, full length, independent release )\\n\\nCountry: The Netherlands\\nStyle: Black Metal"
          }
        },
        {
          "code": "MAYPOST",
          "taken_at": 1779883200,
          "caption": {
            "text": "Older caption outside the requested month"
          }
        }
      ],
      "more_available": false,
      "next_max_id": null
    }
    """
    let context = ResearchContext(
        month: month,
        runID: RunID(),
        crawlClient: DictionaryCrawlClient(pages: [
            feedURL: CrawledPage(url: feedURL, finalURL: feedURL, title: nil, text: json, html: json)
        ]),
        llmFallback: FailingLLMFallback(),
        runsDirectory: FileManager.default.temporaryDirectory,
        knowledgeDirectory: FileManager.default.temporaryDirectory
    )
    let descriptor = EditorialSourceDescriptor(
        name: "InfidelAmsterdam Instagram",
        kind: "instagram_profile",
        sourceURL: URL(string: "https://www.instagram.com/infidelamsterdam/")!,
        username: "infidelamsterdam"
    )

    let documents = try await InstagramProfileEditorialDocumentSource().documents(
        for: month,
        descriptor: descriptor,
        context: context
    )
    let document = try #require(documents.first)

    #expect(documents.count == 1)
    #expect(document.sourceName == "InfidelAmsterdam Instagram")
    #expect(document.sourceKind == "instagram_post")
    #expect(document.itemURL == URL(string: "https://www.instagram.com/p/DZK_hBVsGaZ/")!)
    #expect(document.title == "Instagram post DZK_hBVsGaZ")
    #expect(document.publishedAt.map(MonthlyMetalDateFormatter.shared.format) == "2026-06-04")
    #expect(document.text.contains("New arrivals!"))
    #expect(document.text.contains("Walg: Walg l"))
}

@Test func monthlyMetalScoutWritesCatalogCandidatesAndEditorialDocumentsSeparately() async throws {
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
    let editorialDocumentsJSON = try String(
        contentsOf: result.editorialDocumentsArtifactURL,
        encoding: .utf8
    )

    #expect(result.runID == RunID("test-monthly-metal-scout"))
    #expect(FileManager.default.fileExists(atPath: result.runDirectory.path))
    #expect(FileManager.default.fileExists(atPath: result.candidateArtifactURL.path))
    #expect(FileManager.default.fileExists(atPath: result.potentialCandidatesArtifactURL.path))
    #expect(FileManager.default.fileExists(atPath: result.editorialDocumentsArtifactURL.path))
    #expect(result.candidates.count == 1)
    #expect(result.potentialCandidates.count == 1)
    #expect(lamp.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(lamp.releaseType == "Full-length")
    #expect(lamp.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2025-11-14")
    #expect(lamp.metalArchivesURL == URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!)
    #expect(lamp.sources.map(\.name) == ["Metal Archives monthly search"])
    #expect(editorialDocumentsJSON.contains(#""sourceName" : "Example monthly top albums""#))
    #expect(editorialDocumentsJSON.contains("Editorial Only - Hidden Demo"))
}

@Test func monthlyMetalScoutWritesPotentialCandidatesFromCatalogAndEditorialExtraction() async throws {
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
              "name": "Example editorial source",
              "kind": "ranked_list",
              "url": "https://example.com/editorial",
              "file": "editorial.txt"
            }
          ]
        }
        """,
        files: [
            "editorial.txt": """
            Lamp of Murmuur - The Dreaming Prince in Ecstasy
            Editorial Only - Hidden Demo
            """
        ]
    )

    let scout = MonthlyMetalScout(
        runsDirectory: runsDirectory,
        knowledgeDirectory: knowledgeDirectory,
        runIDProvider: { RunID("test-monthly-metal-potential") },
        crawlClientFactory: { _ in DictionaryCrawlClient(pages: [searchURL: searchPage]) },
        llmProviderFactory: { _ in
            StubLLMProvider(response: """
            {
              "candidates": [
                {
                  "bandName": "Lamp of Murmuur",
                  "albumTitle": "The Dreaming Prince in Ecstasy",
                  "sourceSignal": "mentioned_album",
                  "labelName": null,
                  "releaseDateText": null,
                  "evidence": "Lamp of Murmuur - The Dreaming Prince in Ecstasy",
                  "confidence": 0.8
                },
                {
                  "bandName": "Editorial Only",
                  "albumTitle": "Hidden Demo",
                  "sourceSignal": "mentioned_album",
                  "labelName": "Example Label",
                  "releaseDateText": "November 2025",
                  "evidence": "Editorial Only - Hidden Demo",
                  "confidence": 0.7
                }
              ]
            }
            """)
        }
    )

    let result = try await scout.listCandidates(
        month: "2025-11",
        editorialExtraction: MonthlyMetalLLMExtractionConfiguration(
            baseURL: URL(string: "http://127.0.0.1:8081/v1")!,
            model: "stub-model"
        )
    )
    let potentialCandidatesJSON = try String(
        contentsOf: result.potentialCandidatesArtifactURL,
        encoding: .utf8
    )
    let editorialExtractionJSON = try String(
        contentsOf: try #require(result.editorialExtractionArtifactURL),
        encoding: .utf8
    )
    let lamp = try #require(result.potentialCandidates.first {
        $0.bandName == "Lamp of Murmuur"
    })
    let editorialOnly = try #require(result.potentialCandidates.first {
        $0.bandName == "Editorial Only"
    })

    #expect(result.candidates.count == 1)
    #expect(result.potentialCandidates.count == 2)
    #expect(lamp.sources.count == 2)
    #expect(lamp.sources.contains { $0.kind == "metal_archives_catalog" })
    #expect(lamp.sources.contains { $0.kind == "ranked_list" && $0.signal == "mentioned_album" })
    #expect(editorialOnly.albumTitle == "Hidden Demo")
    #expect(editorialOnly.labelName == "Example Label")
    #expect(editorialOnly.releaseDateText == "November 2025")
    #expect(editorialOnly.metalArchivesURL == nil)
    #expect(editorialOnly.sources.first?.confidence == 0.7)
    #expect(potentialCandidatesJSON.contains("Example editorial source"))
    #expect(potentialCandidatesJSON.contains("Editorial Only"))
    #expect(editorialExtractionJSON.contains("Editorial Only - Hidden Demo"))
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
    #expect(FileManager.default.fileExists(atPath: result.potentialCandidatesArtifactURL.path))
    #expect(FileManager.default.fileExists(atPath: result.editorialDocumentsArtifactURL.path))
    #expect(result.candidates.count == 1)
    #expect(result.potentialCandidates.count == 1)
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

private struct StubLLMProvider: LLMProvider {
    let response: String

    func complete(_ request: LLMRequest) async throws -> String {
        response
    }
}
