import Foundation

struct MetalArchivesAlbumDiscoverySource: ReleaseDiscoverySource {
    private let albumURLs: [URL]

    init(albumURLs: [URL]) {
        self.albumURLs = albumURLs
    }

    func discover(month: Date, context: ResearchContext) async throws -> [ReleaseCandidate] {
        var candidates: [ReleaseCandidate] = []

        for url in albumURLs {
            let page = try await context.crawlClient.fetch(
                CrawlRequest(
                    url: url,
                    source: ResearchSource(rawValue: "metal_archives")
                )
            )

            guard let candidate = MetalArchivesAlbumPageExtractor.shared.extract(from: page) else {
                // Later: diagnostics.skipped(url, reason: .extractionFailed)
                continue
            }

            guard let releaseMonth = Calendar.monthUTC(candidate.releaseDate),
                  releaseMonth == Calendar.monthUTC(month)
            else {
                // Later: diagnostics.skipped(url, reason: .outsideRequestedMonth)
                continue
            }

            candidates.append(candidate)
        }

        return candidates
    }
}
