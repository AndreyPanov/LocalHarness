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
