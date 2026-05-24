import Foundation

protocol ReleaseDiscoverySource: Sendable {
    func discover(month: Date, context: ResearchContext) async throws -> [ReleaseCandidate]
}

protocol BandMetadataSource: Sendable {
    func enrich(_ release: MetalRelease, context: ResearchContext) async throws -> MetalRelease
}

protocol AvailabilitySource: Sendable {
    func check(_ release: MetalRelease, context: ResearchContext) async throws -> MetalRelease
}
