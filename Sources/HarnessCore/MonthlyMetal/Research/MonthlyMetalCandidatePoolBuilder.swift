import Foundation

struct MonthlyMetalCandidatePoolBuilder: Sendable {
    private static let metalArchivesSourceKind = "metal_archives_catalog"

    private let metalArchivesSearchSource: MetalArchivesAdvancedAlbumSearchSource

    init(
        metalArchivesSearchSource: MetalArchivesAdvancedAlbumSearchSource = MetalArchivesAdvancedAlbumSearchSource()
    ) {
        self.metalArchivesSearchSource = metalArchivesSearchSource
    }

    func candidates(for month: Date, context: ResearchContext) async throws -> [MonthlyMetalCandidate] {
        let catalogAlbums = try await metalArchivesSearchSource.albums(for: month, context: context)
        let searchURL = metalArchivesSearchSource.searchURL(for: month)

        var candidatesByIdentity: [MonthlyMetalReleaseIdentity: MonthlyMetalCandidate] = [:]

        for album in catalogAlbums {
            let candidate = MonthlyMetalCandidate(
                bandName: album.bandName,
                albumTitle: album.albumTitle,
                releaseType: album.releaseType,
                labelName: nil,
                releaseDate: album.releaseDate,
                releaseDateText: album.releaseDateText,
                metalArchivesURL: album.albumURL,
                sources: [
                    MonthlyMetalCandidateSource(
                        name: "Metal Archives monthly search",
                        kind: Self.metalArchivesSourceKind,
                        sourceURL: searchURL,
                        itemURL: album.albumURL
                    )
                ]
            )

            candidatesByIdentity[identity(for: candidate)] = candidate
        }

        return candidatesByIdentity.values.sorted(by: shouldSortBefore)
    }

    private func identity(for candidate: MonthlyMetalCandidate) -> MonthlyMetalReleaseIdentity {
        MonthlyMetalReleaseIdentity(
            bandName: candidate.bandName,
            albumTitle: candidate.albumTitle
        )
    }

    private func shouldSortBefore(
        _ lhs: MonthlyMetalCandidate,
        _ rhs: MonthlyMetalCandidate
    ) -> Bool {
        if let lhsDate = lhs.releaseDate,
           let rhsDate = rhs.releaseDate,
           lhsDate != rhsDate
        {
            return lhsDate < rhsDate
        }

        if lhs.releaseDate != nil,
           rhs.releaseDate == nil
        {
            return true
        }

        if lhs.releaseDate == nil,
           rhs.releaseDate != nil
        {
            return false
        }

        if lhs.bandName.localizedCaseInsensitiveCompare(rhs.bandName) != .orderedSame {
            return lhs.bandName.localizedCaseInsensitiveCompare(rhs.bandName) == .orderedAscending
        }

        return lhs.albumTitle.localizedCaseInsensitiveCompare(rhs.albumTitle) == .orderedAscending
    }
}
