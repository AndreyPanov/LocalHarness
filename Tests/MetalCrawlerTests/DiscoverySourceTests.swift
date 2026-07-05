import Foundation
import FileSystemKit
import LocalLLMKit
import SocialSourceKit
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

@Test func metalArchivesAdvancedSearchClientPaginatesFiltersAndDeduplicatesAlbumURLs() async throws {
    let month = try #require(MonthlyMetalDateFormatter.shared.parse("2025-11-01"))
    let searchSource = MetalArchivesAdvancedAlbumSearchClient(
        fetcher: DictionarySocialSourceFetcher(pages: [:]),
        pageSize: 2
    )
    let firstSearchURL = searchSource.searchURL(for: month, start: 0, pageSize: 2)
    let secondSearchURL = searchSource.searchURL(for: month, start: 2, pageSize: 2)
    let firstSearchQueryItems = try #require(URLComponents(
        url: firstSearchURL,
        resolvingAgainstBaseURL: false
    )?.queryItems)
    let source = MetalArchivesAdvancedAlbumSearchClient(
        fetcher: DictionarySocialSourceFetcher(pages: [
            firstSearchURL: try jsonSourcePage(
                url: firstSearchURL,
                fixtureName: "metal-archives-advanced-album-search-2025-11-page-1"
            ),
            secondSearchURL: try jsonSourcePage(
                url: secondSearchURL,
                fixtureName: "metal-archives-advanced-album-search-2025-11-page-2"
            )
        ]),
        pageSize: 2
    )

    let urls = try await source.albumURLs(for: month)

    #expect(firstSearchQueryItems.filter { $0.name == "releaseType[]" }.map(\.value) == ["1", "5"])
    #expect(urls == [
        URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!,
        URL(string: "https://www.metal-archives.com/albums/Dzyan/Dzyan/1386184")!
    ])
}

@Test func metalArchivesAdvancedSearchClientBuildsBandAndAlbumLookupURL() throws {
    let source = MetalArchivesAdvancedAlbumSearchClient(
        fetcher: DictionarySocialSourceFetcher(pages: [:])
    )
    let url = source.searchURL(
        bandName: "Lamp of Murmuur",
        albumTitle: "The Dreaming Prince in Ecstasy",
        start: 0,
        pageSize: 20
    )
    let queryItems = try #require(URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
    )?.queryItems)

    #expect(queryItems.first { $0.name == "bandName" }?.value == "Lamp of Murmuur")
    #expect(queryItems.first { $0.name == "releaseTitle" }?.value == "The Dreaming Prince in Ecstasy")
    #expect(queryItems.filter { $0.name == "releaseType[]" }.map(\.value) == ["1", "5"])
    #expect(queryItems.first { $0.name == "iDisplayLength" }?.value == "20")
}

@Test func metalArchivesAdvancedSearchExtractorAcceptsTitleLookupRowsWithoutDateColumn() throws {
    let searchJSON = #"""
    {
      "iTotalRecords": 1,
      "iTotalDisplayRecords": 1,
      "aaData": [
        [
          "<a href=\"https://www.metal-archives.com/bands/Walg/3540490981\" title=\"Walg (NL)\">Walg</a>",
          "<a href=\"https://www.metal-archives.com/albums/Walg/V/1336529\">V</a> <!-- 17.427197 -->",
          "Full-length"
        ]
      ]
    }
    """#
    let response = try JSONDecoder().decode(
        MetalArchivesAdvancedAlbumSearchResponse.self,
        from: Data(searchJSON.utf8)
    )

    let albums = MetalArchivesAdvancedAlbumSearchExtractor().albums(from: response)
    let album = try #require(albums.first)

    #expect(albums.count == 1)
    #expect(album.bandName == "Walg")
    #expect(album.albumTitle == "V")
    #expect(album.albumURL == URL(string: "https://www.metal-archives.com/albums/Walg/V/1336529")!)
    #expect(album.releaseType == "Full-length")
    #expect(album.releaseDate == nil)
    #expect(album.releaseDateText == nil)
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

@Test func bangerTVSourceProviderKeepsFullVideoDescription() async throws {
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
    let sourceProvider = SocialSourceClient(
        fetcher: DictionarySocialSourceFetcher(pages: [
            feedURL: SocialSourcePage(url: feedURL, finalURL: feedURL, text: feedXML, html: feedXML),
            videoURL: SocialSourcePage(url: videoURL, finalURL: videoURL, text: videoHTML, html: videoHTML)
        ])
    )
    let descriptor = SourceProviderDescriptor(
        name: "BangerTV",
        kind: "youtube_channel",
        sourceURL: URL(string: "https://www.youtube.com/@BangerTV")!,
        channelID: "test-channel"
    )

    let sourceItems = try await BangerTVSourceProvider(
        sourceProvider: sourceProvider
    ).sourceItems(
        for: month,
        descriptor: descriptor
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

@Test func instagramProfileSourceProviderKeepsFullPostCaptions() async throws {
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
    let sourceProvider = SocialSourceClient(
        fetcher: DictionarySocialSourceFetcher(pages: [
            feedURL: SocialSourcePage(url: feedURL, finalURL: feedURL, text: json, html: json)
        ])
    )
    let descriptor = SourceProviderDescriptor(
        name: "InfidelAmsterdam Instagram",
        kind: "instagram_profile",
        sourceURL: URL(string: "https://www.instagram.com/infidelamsterdam/")!,
        username: "infidelamsterdam"
    )

    let sourceItems = try await InstagramProfileSourceProvider(
        sourceProvider: sourceProvider
    ).sourceItems(
        for: month,
        descriptor: descriptor
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

@Test func monthlyMetalSourceItemProviderLoadsGlobalSourcesWithoutMonthManifest() async throws {
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

    defer { try? FileSystem.shared.removeItem(at: temporaryDirectory) }

    try writeGlobalSourceProvider(
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

    let sourceItems = try await MonthlyMetalSourceItemProvider(
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

    defer { try? FileSystem.shared.removeItem(at: temporaryDirectory) }

    try writeGlobalSourceProvider(
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
    let sourceItemsJSON = try FileSystem.shared.readText(from: result.sourceItemsArtifactURL)
    let potentialCandidatesArtifact = try FileSystem.shared.readJSON(
        TestMonthlyMetalPotentialCandidateArtifact.self,
        from: result.potentialCandidatesArtifactURL
    )

    #expect(result.runID == RunID("test-monthly-metal-crawler"))
    #expect(FileSystem.shared.exists(result.runDirectory))
    #expect(FileSystem.shared.exists(result.potentialCandidatesArtifactURL))
    #expect(FileSystem.shared.exists(result.sourceItemsArtifactURL))
    #expect(result.sourceExtractionArtifactURL == nil)
    #expect(result.sourceItems.count == 1)
    #expect(result.extractedSourceItemCount == 0)
    #expect(result.extractedCandidateMentionCount == 0)
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

    defer { try? FileSystem.shared.removeItem(at: temporaryDirectory) }

    try writeGlobalSourceProvider(
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
    let potentialCandidatesJSON = try FileSystem.shared.readText(from: result.potentialCandidatesArtifactURL)
    let sourceExtractionJSON = try FileSystem.shared.readText(
        from: try #require(result.sourceExtractionArtifactURL)
    )
    let lamp = try #require(result.potentialCandidates.first {
        $0.bandName == "Lamp of Murmuur"
    })
    let sourceOnly = try #require(result.potentialCandidates.first {
        $0.bandName == "Source Only"
    })

    #expect(result.sourceItems.count == 1)
    #expect(result.extractedSourceItemCount == 1)
    #expect(result.extractedCandidateMentionCount == 2)
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

@Test func monthlyMetalCrawlerWritesMetalArchivesEnrichedCandidates() async throws {
    let temporaryDirectory = try makeTemporaryDirectory()
    let runsDirectory = temporaryDirectory.appendingPathComponent("runs", isDirectory: true)
    let knowledgeDirectory = temporaryDirectory.appendingPathComponent("knowledge", isDirectory: true)
    let albumURL = URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!
    let bandURL = URL(string: "https://www.metal-archives.com/bands/Lamp_of_Murmuur/3540453255")!
    let discographyURL = URL(string: "https://www.metal-archives.com/band/discography/id/3540453255/tab/all")!
    let searchURL = MetalArchivesAdvancedAlbumSearchClient(
        fetcher: DictionarySocialSourceFetcher(pages: [:])
    ).searchURL(
        bandName: "Lamp of Murmuur",
        albumTitle: "The Dreaming Prince in Ecstasy",
        start: 0,
        pageSize: 20
    )
    let albumHTML = try fixtureString(
        named: "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives",
        fileExtension: "html"
    )
    let searchJSON = #"""
    {
      "iTotalRecords": 1,
      "iTotalDisplayRecords": 1,
      "aaData": [
        [
          "<a href=\"https://www.metal-archives.com/bands/Lamp_of_Murmuur/3540453255\">Lamp of Murmuur</a>",
          "<a href=\"https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559\">The Dreaming Prince in Ecstasy</a>",
          "Full-length",
          "<!-- 2025-11-14 -->November 14th, 2025"
        ]
      ]
    }
    """#
    let bandHTML = """
    <div id="band_info">
      <dl class="float_left">
        <dt>Status:</dt><dd>Active</dd>
        <dt>Formed in:</dt><dd>2019</dd>
      </dl>
      <dl class="float_right">
        <dt>Genre:</dt><dd>Raw Black Metal</dd>
        <dt>Lyrical themes:</dt><dd>Night, mysticism</dd>
        <dt>Years active:</dt><dd>2019-present</dd>
      </dl>
      <a href="https://www.metal-archives.com/band/discography/id/3540453255/tab/all">Discography</a>
    </div>
    <div id="band_tab_members_current">
      <table class="display line-up">
        <tr><td><a href="https://www.metal-archives.com/artists/M./1">M.</a></td><td>Everything</td></tr>
        <tr><td><a href="https://www.metal-archives.com/artists/N./2">N.</a></td><td>Drums</td></tr>
      </table>
    </div>
    """
    let discographyHTML = """
    <table class="display discog">
      <tr><td>Demo I</td><td>Demo</td><td>2019</td></tr>
      <tr><td>Album I</td><td>Full-length</td><td>2020</td></tr>
      <tr><td>EP I</td><td>EP</td><td>2021</td></tr>
      <tr><td>Album II</td><td>Full-length</td><td>2024</td></tr>
    </table>
    """
    let bangerTVFixture = try bangerTVMonthlyFixture(
        description: """
        Lamp of Murmuur
        The Dreaming Prince in Ecstasy
        November 14th, 2025
        """
    )
    var pages = bangerTVFixture.pages

    pages[searchURL] = CrawledPage(
        url: searchURL,
        finalURL: searchURL,
        title: nil,
        text: searchJSON,
        html: searchJSON
    )
    pages[albumURL] = CrawledPage(
        url: albumURL,
        finalURL: albumURL,
        title: nil,
        text: albumHTML,
        html: albumHTML
    )
    pages[bandURL] = CrawledPage(
        url: bandURL,
        finalURL: bandURL,
        title: nil,
        text: bandHTML,
        html: bandHTML
    )
    pages[discographyURL] = CrawledPage(
        url: discographyURL,
        finalURL: discographyURL,
        title: nil,
        text: discographyHTML,
        html: discographyHTML
    )
    let crawlPages = pages

    defer { try? FileSystem.shared.removeItem(at: temporaryDirectory) }

    try writeGlobalSourceProvider(
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
        runIDProvider: { RunID("test-monthly-metal-enrichment") },
        crawlClientFactory: { _ in DictionaryCrawlClient(pages: crawlPages) },
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
    let enrichedArtifact = try FileSystem.shared.readJSON(
        TestMonthlyMetalEnrichedCandidateArtifact.self,
        from: result.enrichedCandidatesArtifactURL
    )
    let enrichedJSON = try FileSystem.shared.readText(from: result.enrichedCandidatesArtifactURL)
    let enriched = try #require(result.enrichedCandidates.first)

    #expect(result.potentialCandidates.count == 1)
    #expect(result.enrichedCandidates.count == 1)
    #expect(enriched.status == .matched)
    #expect(enriched.candidate.metalArchivesURL == albumURL)
    #expect(enriched.candidate.labelName == "Wolves of Hades")
    #expect(enriched.metalArchives?.genre == "Raw Black Metal")
    #expect(enriched.metalArchives?.lyricalThemes == "Night, mysticism")
    #expect(enriched.metalArchives?.fullLengthAlbumCount == 2)
    #expect(enriched.metalArchives?.fullTimeMemberCount == 2)
    #expect(enriched.metalArchives?.reviewCount == 2)
    #expect(enriched.metalArchives?.averageReviewScore == 92)
    #expect(enrichedArtifact.month == "2026-06")
    #expect(enrichedArtifact.candidates.first?.status == .matched)
    #expect(enrichedJSON.contains(#""status" : "matched""#))
    #expect(enrichedJSON.contains(#""genre" : "Raw Black Metal""#))
}

private func fixtureString(named name: String, fileExtension: String) throws -> String {
    let fixtureURL = try #require(Bundle.module.url(
        forResource: name,
        withExtension: fileExtension,
        subdirectory: "Fixtures"
    ))

    return try FileSystem.shared.readText(from: fixtureURL)
}

private func jsonSourcePage(url: URL, fixtureName: String) throws -> SocialSourcePage {
    let json = try fixtureString(named: fixtureName, fileExtension: "json")

    return SocialSourcePage(
        url: url,
        finalURL: url,
        text: json,
        html: json
    )
}

private func makeTemporaryDirectory() throws -> URL {
    try FileSystem.shared.makeTemporaryDirectory(baseName: "metal-crawler-tests")
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

private func writeGlobalSourceProvider(
    knowledgeDirectory: URL,
    manifest: String
) throws {
    let sourceDirectory = knowledgeDirectory
        .appendingPathComponent("source-providers", isDirectory: true)

    try FileSystem.shared.writePrettyJSONPayload(manifest, fileName: "sources.json", in: sourceDirectory)
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

private struct DictionarySocialSourceFetcher: SocialSourceFetching {
    let pages: [URL: SocialSourcePage]

    func fetch(_ request: SocialSourceRequest) async throws -> SocialSourcePage {
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

private struct TestMonthlyMetalEnrichedCandidateArtifact: Decodable {
    let month: String
    let candidates: [MonthlyMetalEnrichedCandidate]
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
