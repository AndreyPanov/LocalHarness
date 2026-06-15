import Foundation
import Testing
@testable import HarnessCore

@Test func metalArchivesAlbumExtractorBuildsReleaseCandidate() throws {
    let url = URL(string: "https://www.metal-archives.com/albums/Lamp_of_Murmuur/The_Dreaming_Prince_in_Ecstasy/1369559")!

    let fixtureURL = try #require(Bundle.module.url(
        forResource: "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives",
        withExtension: "html",
        subdirectory: "Fixtures"
    ))
    let html = try String(contentsOf: fixtureURL, encoding: .utf8)

    let page = CrawledPage(
        url: url,
        finalURL: url,
        title: "Lamp of Murmuur - The Dreaming Prince in Ecstasy - Encyclopaedia Metallum: The Metal Archives",
        text: HTMLTextExtractor.shared.visibleText(from: html),
        html: html
    )

    let candidate = try #require(MetalArchivesAlbumPageExtractor.shared.extract(from: page))

    #expect(candidate.bandName == "Lamp of Murmuur")
    #expect(candidate.albumTitle == "The Dreaming Prince in Ecstasy")
    #expect(candidate.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2025-11-14")
    #expect(candidate.sources.first?.name == "metal_archives")
    #expect(candidate.sources.first?.url == url)
}
