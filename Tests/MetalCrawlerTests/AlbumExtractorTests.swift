import Foundation
import FileSystemKit
import SocialSourceKit
import Testing
@testable import MetalCrawlerCore

@Test func metalArchivesAlbumExtractorBuildsReleaseCandidate() throws {
    let url = URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!

    let fixtureURL = try #require(Bundle.module.url(
        forResource: "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives",
        withExtension: "html",
        subdirectory: "Fixtures"
    ))
    let html = try FileSystem.shared.readText(from: fixtureURL)

    let page = SocialSourcePage(
        url: url,
        finalURL: url,
        text: html,
        html: html
    )

    let album = try #require(MetalArchivesAlbumPageExtractor.shared.extractAlbum(from: page))

    #expect(album.bandName == "Lamp of Murmuur")
    #expect(album.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(album.releaseType == "Full-length")
    #expect(album.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2025-11-14")
    #expect(album.albumURL == url)
}

@Test func metalArchivesAlbumExtractorBuildsRecommendationEnrichment() throws {
    let url = URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!
    let bandURL = URL(string: "https://www.metal-archives.com/bands/Lamp_of_Murmuur/3540453255")!

    let fixtureURL = try #require(Bundle.module.url(
        forResource: "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives",
        withExtension: "html",
        subdirectory: "Fixtures"
    ))
    let html = try FileSystem.shared.readText(from: fixtureURL)
    let page = SocialSourcePage(
        url: url,
        finalURL: url,
        text: html,
        html: html
    )

    let enrichment = try #require(MetalArchivesAlbumPageExtractor.shared.extractAlbumEnrichment(from: page))

    #expect(enrichment.bandName == "Lamp of Murmuur")
    #expect(enrichment.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(enrichment.albumURL == url)
    #expect(enrichment.bandURL == bandURL)
    #expect(enrichment.labelName == "Wolves of Hades")
    #expect(enrichment.releaseType == "Full-length")
    #expect(enrichment.reviewCount == 2)
    #expect(enrichment.averageReviewScore == 92)
}

@Test func metalArchivesBandExtractorBuildsRecommendationEnrichment() throws {
    let bandURL = URL(string: "https://www.metal-archives.com/bands/Lamp_of_Murmuur/3540453255")!
    let discographyURL = URL(string: "https://www.metal-archives.com/band/discography/id/3540453255/tab/all")!
    let html = """
    <div id="band_info">
      <dl class="float_left">
        <dt>Status:</dt>
        <dd>Active</dd>
        <dt>Formed in:</dt>
        <dd>2019</dd>
      </dl>
      <dl class="float_right">
        <dt>Genre:</dt>
        <dd>Raw Black Metal</dd>
        <dt>Lyrical themes:</dt>
        <dd>Night, mysticism</dd>
        <dt>Years active:</dt>
        <dd>2019-present</dd>
      </dl>
      <a href="https://www.metal-archives.com/band/discography/id/3540453255/tab/all">Discography</a>
    </div>
    <div id="band_tab_members_current">
      <table class="display line-up">
        <tr class="lineupHeaders"><td colspan="2">Current lineup</td></tr>
        <tr><td><a href="https://www.metal-archives.com/artists/M./1">M.</a></td><td>Everything</td></tr>
        <tr><td><a href="https://www.metal-archives.com/artists/N./2">N.</a></td><td>Drums</td></tr>
      </table>
    </div>
    """
    let page = SocialSourcePage(
        url: bandURL,
        finalURL: bandURL,
        text: html,
        html: html
    )

    let enrichment = try #require(MetalArchivesAlbumPageExtractor(currentYear: 2026).extractBandEnrichment(from: page))

    #expect(enrichment.bandURL == bandURL)
    #expect(enrichment.genre == "Raw Black Metal")
    #expect(enrichment.lyricalThemes == "Night, mysticism")
    #expect(enrichment.yearsActive == 7)
    #expect(enrichment.fullTimeMemberCount == 2)
    #expect(enrichment.discographyURL == discographyURL)
}

@Test func metalArchivesDiscographyExtractorCountsFullLengthAlbums() throws {
    let html = """
    <table class="display discog">
      <tr><td>Demo I</td><td>Demo</td><td>2019</td></tr>
      <tr><td>Album I</td><td>Full-length</td><td>2020</td></tr>
      <tr><td>EP I</td><td>EP</td><td>2021</td></tr>
      <tr><td>Album II</td><td>Full-length</td><td>2024</td></tr>
    </table>
    """

    #expect(MetalArchivesAlbumPageExtractor.shared.fullLengthAlbumCount(fromDiscographyHTML: html) == 2)
}
