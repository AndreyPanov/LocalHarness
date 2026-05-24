protocol LLMExtractionFallback: Sendable {
    func extractReleaseCandidate(from page: CrawledPage) async throws -> ReleaseCandidate
    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft
}
