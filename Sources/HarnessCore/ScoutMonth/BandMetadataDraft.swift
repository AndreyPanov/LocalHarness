import Foundation

struct BandMetadataDraft: Codable, Sendable {
    let country: String?
    let genre: String?
    let formationDate: Date?
    let history: String?
    let confidence: Double
}

struct BandcampAvailabilityDraft: Codable, Sendable {
    let albumURL: URL?
    let hasDigital: Bool?
    let hasCD: Bool?
    let digitalResolution: DigitalAudioResolution?
    let confidence: Double
}
