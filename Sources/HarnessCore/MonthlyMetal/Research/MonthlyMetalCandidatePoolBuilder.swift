import Foundation

struct MonthlyMetalCandidatePoolBuilder: Sendable {
    private static let metalArchivesSourceKind = "metal_archives_catalog"

    private let metalArchivesSearchSource: MetalArchivesAdvancedAlbumSearchSource
    private let editorialSeedSource: EditorialReleaseSeedSource

    init(
        metalArchivesSearchSource: MetalArchivesAdvancedAlbumSearchSource = MetalArchivesAdvancedAlbumSearchSource(),
        editorialSeedSource: EditorialReleaseSeedSource
    ) {
        self.metalArchivesSearchSource = metalArchivesSearchSource
        self.editorialSeedSource = editorialSeedSource
    }

    func candidates(for month: Date, context: ResearchContext) async throws -> [MonthlyMetalCandidate] {
        let catalogAlbums = try await metalArchivesSearchSource.albums(for: month, context: context)
        let editorialSeeds = try editorialSeedSource.seeds(for: month)
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

        for seed in editorialSeeds {
            let seedIdentity = identity(for: seed)

            if let existingCandidate = candidatesByIdentity[seedIdentity] {
                candidatesByIdentity[seedIdentity] = merge(existingCandidate, with: seed)
            } else {
                candidatesByIdentity[seedIdentity] = MonthlyMetalCandidate(
                    bandName: seed.bandName,
                    albumTitle: seed.albumTitle,
                    releaseType: nil,
                    labelName: seed.labelName,
                    releaseDate: seed.releaseDate,
                    releaseDateText: seed.releaseDateText,
                    metalArchivesURL: nil,
                    sources: [seed.source]
                )
            }
        }

        return candidatesByIdentity.values.sorted(by: shouldSortBefore)
    }

    private func merge(
        _ candidate: MonthlyMetalCandidate,
        with seed: EditorialReleaseSeed
    ) -> MonthlyMetalCandidate {
        MonthlyMetalCandidate(
            bandName: candidate.bandName,
            albumTitle: candidate.albumTitle,
            releaseType: candidate.releaseType,
            labelName: candidate.labelName ?? seed.labelName,
            releaseDate: candidate.releaseDate ?? seed.releaseDate,
            releaseDateText: candidate.releaseDateText ?? seed.releaseDateText,
            metalArchivesURL: candidate.metalArchivesURL,
            sources: appendingUnique(seed.source, to: candidate.sources)
        )
    }

    private func appendingUnique(
        _ source: MonthlyMetalCandidateSource,
        to sources: [MonthlyMetalCandidateSource]
    ) -> [MonthlyMetalCandidateSource] {
        guard !sources.contains(source) else {
            return sources
        }

        return sources + [source]
    }

    private func identity(for candidate: MonthlyMetalCandidate) -> MonthlyMetalReleaseIdentity {
        MonthlyMetalReleaseIdentity(
            bandName: candidate.bandName,
            albumTitle: candidate.albumTitle
        )
    }

    private func identity(for seed: EditorialReleaseSeed) -> MonthlyMetalReleaseIdentity {
        MonthlyMetalReleaseIdentity(
            bandName: seed.bandName,
            albumTitle: seed.albumTitle
        )
    }

    private func shouldSortBefore(
        _ lhs: MonthlyMetalCandidate,
        _ rhs: MonthlyMetalCandidate
    ) -> Bool {
        let lhsEditorialRank = editorialRank(for: lhs)
        let rhsEditorialRank = editorialRank(for: rhs)

        if lhsEditorialRank != rhsEditorialRank {
            return lhsEditorialRank < rhsEditorialRank
        }

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

    private func editorialRank(for candidate: MonthlyMetalCandidate) -> Int {
        candidate.sources
            .filter { $0.kind != Self.metalArchivesSourceKind }
            .compactMap(\.rank)
            .min() ?? Int.max
    }
}
