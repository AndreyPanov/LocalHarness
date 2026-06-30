import Foundation
import Testing
@testable import MetalCrawlerCore

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

@Test func bangerTVSourceItemProviderKeepsFullVideoDescription() async throws {
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
    let descriptor = CrawlSourceDescriptor(
        name: "BangerTV",
        kind: "youtube_channel",
        sourceURL: URL(string: "https://www.youtube.com/@BangerTV")!,
        channelID: "test-channel"
    )

    let sourceItems = try await BangerTVSourceItemProvider().sourceItems(
        for: month,
        descriptor: descriptor,
        context: context
    )
    let sourceItem = try #require(sourceItems.first)

    #expect(sourceItems.count == 1)
    #expect(sourceItem.sourceName == "BangerTV")
    #expect(sourceItem.sourceKind == "youtube_album_review")
    #expect(sourceItem.sourceURL == URL(string: "https://www.youtube.com/@BangerTV")!)
    #expect(sourceItem.itemURL == videoURL)
    #expect(sourceItem.title == "KHEMMIS  Khemmis | BangerTV Metal Album Reviews")
    #expect(sourceItem.publishedAt.map(MonthlyMetalDateFormatter.shared.format) == "2026-06-19")
    #expect(sourceItem.text.contains("Mork - Monolitt - June 19th, 2026 - Peaceville Records"))
}

@Test func instagramSourceItemProviderKeepsFullPostCaptions() async throws {
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
    let descriptor = CrawlSourceDescriptor(
        name: "InfidelAmsterdam Instagram",
        kind: "instagram_profile",
        sourceURL: URL(string: "https://www.instagram.com/infidelamsterdam/")!,
        username: "infidelamsterdam"
    )

    let sourceItems = try await InstagramProfileSourceItemProvider().sourceItems(
        for: month,
        descriptor: descriptor,
        context: context
    )
    let sourceItem = try #require(sourceItems.first)

    #expect(sourceItems.count == 1)
    #expect(sourceItem.sourceName == "InfidelAmsterdam Instagram")
    #expect(sourceItem.sourceKind == "instagram_post")
    #expect(sourceItem.itemURL == URL(string: "https://www.instagram.com/p/DZK_hBVsGaZ/")!)
    #expect(sourceItem.title == "Instagram post DZK_hBVsGaZ")
    #expect(sourceItem.publishedAt.map(MonthlyMetalDateFormatter.shared.format) == "2026-06-04")
    #expect(sourceItem.text.contains("New arrivals!"))
    #expect(sourceItem.text.contains("Walg: Walg l"))
}

@Test func crawlSourceItemProviderLoadsGlobalSourcesWithoutMonthManifest() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    let knowledgeDirectory = temporaryDirectory.appendingPathComponent("knowledge", isDirectory: true)
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2026-05-01"))
    let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=test-channel")!
    let videoURL = URL(string: "https://www.youtube.com/watch?v=may-monthly")!
    let feedXML = """
    <feed>
      <entry>
        <yt:videoId>may-monthly</yt:videoId>
        <title>METAL MONTHLY MAY 2026 | Example Band</title>
        <published>2026-05-10T15:19:20+00:00</published>
      </entry>
    </feed>
    """
    let videoHTML = #"""
    <script>
    var ytInitialPlayerResponse = {"videoDetails":{"shortDescription":"Example Band\nExample Album\nExample Label\nMay 2026"}};
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
        runsDirectory: temporaryDirectory,
        knowledgeDirectory: knowledgeDirectory
    )

    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try writeGlobalCrawlSource(
        knowledgeDirectory: knowledgeDirectory,
        manifest: """
        {
          "sources": [
            {
              "name": "BangerTV",
              "kind": "youtube_channel",
              "url": "https://www.youtube.com/@BangerTV",
              "channelID": "test-channel"
            }
          ]
        }
        """
    )

    let sourceItems = try await CrawlSourceItemProvider(
        knowledgeDirectory: knowledgeDirectory
    ).sourceItems(for: month, context: context)
    let sourceItem = try #require(sourceItems.first)

    #expect(sourceItems.count == 1)
    #expect(sourceItem.sourceName == "BangerTV")
    #expect(sourceItem.sourceKind == "youtube_monthly")
    #expect(sourceItem.itemURL == videoURL)
    #expect(sourceItem.title == "METAL MONTHLY MAY 2026 | Example Band")
    #expect(sourceItem.text.contains("Example Band"))
    #expect(sourceItem.text.contains("Example Album"))
}

@Test func monthlyMetalCrawlerWritesSourceItemsWithoutExtraction() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    let runsDirectory = temporaryDirectory.appendingPathComponent("runs", isDirectory: true)
    let knowledgeDirectory = temporaryDirectory.appendingPathComponent("knowledge", isDirectory: true)
    let bangerTVFixture = try bangerTVMonthlyFixture(
        description: """
        Example Band
        Example Album
        Example Label
        June 6th, 2026
        https://example.com/example-band
        """
    )

    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try writeGlobalCrawlSource(
        knowledgeDirectory: knowledgeDirectory,
        manifest: """
        {
          "sources": [
            {
              "name": "BangerTV",
              "kind": "youtube_channel",
              "url": "https://www.youtube.com/@BangerTV",
              "channelID": "test-channel"
            }
          ]
        }
        """
    )

    let crawler = MonthlyMetalCrawler(
        runsDirectory: runsDirectory,
        knowledgeDirectory: knowledgeDirectory,
        runIDProvider: { RunID("test-monthly-metal-crawler") },
        crawlClientFactory: { _ in DictionaryCrawlClient(pages: bangerTVFixture.pages) }
    )

    let result = try await crawler.listCandidates(month: "2026-06")
    let sourceItemsJSON = try String(
        contentsOf: result.sourceItemsArtifactURL,
        encoding: .utf8
    )
    let potentialCandidatesArtifact = try JSONDecoder().decode(
        TestMonthlyMetalPotentialCandidateArtifact.self,
        from: Data(contentsOf: result.potentialCandidatesArtifactURL)
    )

    #expect(result.runID == RunID("test-monthly-metal-crawler"))
    #expect(FileManager.default.fileExists(atPath: result.runDirectory.path))
    #expect(FileManager.default.fileExists(atPath: result.potentialCandidatesArtifactURL.path))
    #expect(FileManager.default.fileExists(atPath: result.sourceItemsArtifactURL.path))
    #expect(result.sourceExtractionArtifactURL == nil)
    #expect(result.sourceItems.count == 1)
    #expect(result.potentialCandidates.isEmpty)
    #expect(result.sourceItems.first?.sourceName == "BangerTV")
    #expect(result.sourceItems.first?.sourceKind == "youtube_monthly")
    #expect(result.sourceItems.first?.itemURL == bangerTVFixture.videoURL)
    #expect(sourceItemsJSON.contains(#""sourceName" : "BangerTV""#))
    #expect(sourceItemsJSON.contains("Example Album"))
    #expect(potentialCandidatesArtifact.month == "2026-06")
    #expect(potentialCandidatesArtifact.candidates.isEmpty)
}

@Test func monthlyMetalCrawlerWritesPotentialCandidatesFromSourceExtraction() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    let runsDirectory = temporaryDirectory.appendingPathComponent("runs", isDirectory: true)
    let knowledgeDirectory = temporaryDirectory.appendingPathComponent("knowledge", isDirectory: true)
    let bangerTVFixture = try bangerTVMonthlyFixture(
        description: """
        Lamp of Murmuur
        The Dreaming Prince in Ecstasy
        Example Label
        November 14th, 2025

        Source Only
        Hidden Demo
        Example Label
        November 2025
        """
    )

    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try writeGlobalCrawlSource(
        knowledgeDirectory: knowledgeDirectory,
        manifest: """
        {
          "sources": [
            {
              "name": "BangerTV",
              "kind": "youtube_channel",
              "url": "https://www.youtube.com/@BangerTV",
              "channelID": "test-channel"
            }
          ]
        }
        """
    )

    let crawler = MonthlyMetalCrawler(
        runsDirectory: runsDirectory,
        knowledgeDirectory: knowledgeDirectory,
        runIDProvider: { RunID("test-monthly-metal-potential") },
        crawlClientFactory: { _ in DictionaryCrawlClient(pages: bangerTVFixture.pages) },
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
                  "bandName": "Source Only",
                  "albumTitle": "Hidden Demo",
                  "sourceSignal": "mentioned_album",
                  "labelName": "Example Label",
                  "releaseDateText": "November 2025",
                  "evidence": "Source Only - Hidden Demo",
                  "confidence": 0.7
                }
              ]
            }
            """)
        }
    )

    let result = try await crawler.listCandidates(
        month: "2026-06",
        sourceExtraction: MonthlyMetalSourceExtractionConfiguration(
            baseURL: URL(string: "http://127.0.0.1:8082/v1")!,
            model: "stub-model"
        )
    )
    let potentialCandidatesJSON = try String(
        contentsOf: result.potentialCandidatesArtifactURL,
        encoding: .utf8
    )
    let sourceExtractionJSON = try String(
        contentsOf: try #require(result.sourceExtractionArtifactURL),
        encoding: .utf8
    )
    let lamp = try #require(result.potentialCandidates.first {
        $0.bandName == "Lamp of Murmuur"
    })
    let sourceOnly = try #require(result.potentialCandidates.first {
        $0.bandName == "Source Only"
    })

    #expect(result.sourceItems.count == 1)
    #expect(result.potentialCandidates.count == 2)
    #expect(lamp.sources.count == 1)
    #expect(lamp.metalArchivesURL == nil)
    #expect(lamp.sources.contains { $0.kind == "youtube_monthly" && $0.signal == "mentioned_album" })
    #expect(sourceOnly.albumTitle == "Hidden Demo")
    #expect(sourceOnly.labelName == "Example Label")
    #expect(sourceOnly.releaseDateText == "November 2025")
    #expect(sourceOnly.metalArchivesURL == nil)
    #expect(sourceOnly.sources.first?.confidence == 0.7)
    #expect(potentialCandidatesJSON.contains("BangerTV"))
    #expect(potentialCandidatesJSON.contains("Source Only"))
    #expect(sourceExtractionJSON.contains("Source Only - Hidden Demo"))
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
        .appendingPathComponent("metal-crawler-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private struct BangerTVFixture {
    let videoURL: URL
    let pages: [URL: CrawledPage]
}

private func bangerTVMonthlyFixture(description: String) throws -> BangerTVFixture {
    let feedURL = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=test-channel")!
    let videoID = "monthly-video"
    let videoURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
    let feedXML = """
    <feed>
      <entry>
        <yt:videoId>\(videoID)</yt:videoId>
        <title>METAL MONTHLY JUNE 2026 | Example Band</title>
        <published>2026-06-03T15:19:20+00:00</published>
      </entry>
    </feed>
    """
    let playerResponseData = try JSONSerialization.data(
        withJSONObject: ["videoDetails": ["shortDescription": description]]
    )
    let playerResponse = String(data: playerResponseData, encoding: .utf8)!
    let videoHTML = """
    <script>
    var ytInitialPlayerResponse = \(playerResponse);
    </script>
    """

    return BangerTVFixture(
        videoURL: videoURL,
        pages: [
            feedURL: CrawledPage(
                url: feedURL,
                finalURL: feedURL,
                title: nil,
                text: feedXML,
                html: feedXML
            ),
            videoURL: CrawledPage(
                url: videoURL,
                finalURL: videoURL,
                title: nil,
                text: videoHTML,
                html: videoHTML
            )
        ]
    )
}

private func writeGlobalCrawlSource(
    knowledgeDirectory: URL,
    manifest: String
) throws {
    let sourceDirectory = knowledgeDirectory
        .appendingPathComponent("crawl-sources", isDirectory: true)

    try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
    try manifest.write(
        to: sourceDirectory.appendingPathComponent("sources.json", isDirectory: false),
        atomically: true,
        encoding: .utf8
    )
}

private struct DictionaryCrawlClient: CrawlClient {
    let pages: [URL: CrawledPage]

    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        guard let page = pages[request.url] else {
            throw MonthlyMetalError.invalidCrawlResponse(request.url.absoluteString)
        }

        return page
    }
}

private struct TestMonthlyMetalPotentialCandidateArtifact: Decodable {
    let month: String
    let candidates: [MonthlyMetalCandidate]
}

private struct FailingLLMFallback: LLMExtractionFallback {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate {
        throw MonthlyMetalError.invalidOperation("LLM fallback should not be used in this test.")
    }

    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft {
        throw MonthlyMetalError.invalidOperation("LLM fallback should not be used in this test.")
    }
}

private struct StubLLMProvider: LLMProvider {
    let response: String

    func complete(_ request: LLMRequest) async throws -> String {
        response
    }
}
