import Foundation
import Testing
@testable import HarnessCore

@Test func metalArchivesAlbumExtractorBuildsReleaseCandidate() throws {
    let url = URL(string: "https://www.metal-archives.com/albums/Test_Band/Test_Album/123")!

    let html = """
    <html>
      <head>
        <title>Test Band - Test Album - Encyclopaedia Metallum</title>
      </head>
      <body>
        <h1 class="band_name">
          <a href="https://www.metal-archives.com/bands/Test_Band/1">Test Band</a>
        </h1>
        <h1 class="album_name">
          <a href="https://www.metal-archives.com/albums/Test_Band/Test_Album/123">Test Album</a>
        </h1>
        <dl class="float_left">
          <dt>Type:</dt>
          <dd>Full-length</dd>
          <dt>Release date:</dt>
          <dd>May 10th, 2026</dd>
        </dl>
      </body>
    </html>
    """

    let page = CrawledPage(
        url: url,
        finalURL: url,
        title: "Test Band - Test Album - Encyclopaedia Metallum",
        text: HTMLTextExtractor.shared.visibleText(from: html),
        html: html
    )

    let candidate = try #require(MetalArchivesAlbumPageExtractor.shared.extract(from: page))

    #expect(candidate.bandName == "Test Band")
    #expect(candidate.albumTitle == "Test Album")
    #expect(candidate.releaseDate.map(MonthlyMetalDateFormatter.shared.format) == "2026-05-10")
    #expect(candidate.sources.first?.name == "metal_archives")
    #expect(candidate.sources.first?.url == url)
}
