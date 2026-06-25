import Foundation

struct BandcampAvailabilityDraft: Codable, Sendable {
    let albumURL: URL?
    let hasDigital: Bool?
    let hasCD: Bool?
    let digitalResolution: DigitalAudioResolution?
    let confidence: Double
}
