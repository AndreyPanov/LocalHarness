import Foundation

struct MetalArchivesMonthlyReleaseDiscoverySource: ReleaseDiscoverySource {
    private let searchSource: MetalArchivesAdvancedAlbumSearchSource

    init(searchSource: MetalArchivesAdvancedAlbumSearchSource = MetalArchivesAdvancedAlbumSearchSource()) {
        self.searchSource = searchSource
    }

    func discover(month: Date, context: ResearchContext) async throws -> [ReleaseCandidate] {
        let albumURLs = try await searchSource.albumURLs(for: month, context: context)
        let albumSource = MetalArchivesAlbumDiscoverySource(albumURLs: albumURLs)

        return try await albumSource.discover(month: month, context: context)
    }
}
