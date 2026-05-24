protocol LLMExtractionFallback: Sendable {
    func extractBandMetadata(from page: CrawledPage) async throws -> BandMetadataDraft
    func extractBandcampAvailability(from page: CrawledPage) async throws -> BandcampAvailabilityDraft
}
