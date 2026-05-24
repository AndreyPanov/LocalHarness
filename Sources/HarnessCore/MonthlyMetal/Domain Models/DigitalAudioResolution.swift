import Foundation

public struct DigitalAudioResolution: Codable, Hashable, Sendable {
    public let bitDepth: BitDepth
    public let sampleRate: SampleRate

    public init(bitDepth: BitDepth, sampleRate: SampleRate) {
        self.bitDepth = bitDepth
        self.sampleRate = sampleRate
    }

    public static let lossless16_44_1 = Self(bitDepth: .bit16, sampleRate: .khz44_1)
    public static let hiRes24_44_1 = Self(bitDepth: .bit24, sampleRate: .khz44_1)
    public static let hiRes24_48 = Self(bitDepth: .bit24, sampleRate: .khz48)
    public static let hiRes24_88_2 = Self(bitDepth: .bit24, sampleRate: .khz88_2)
    public static let hiRes24_96 = Self(bitDepth: .bit24, sampleRate: .khz96)

    public static let supported: Set<Self> = [
        .lossless16_44_1,
        .hiRes24_44_1,
        .hiRes24_48,
        .hiRes24_88_2,
        .hiRes24_96
    ]

    public var isSupported: Bool {
        Self.supported.contains(self)
    }
    
    public enum BitDepth: Int, Codable, Hashable, Sendable {
        case bit16 = 16
        case bit24 = 24
    }

    public enum SampleRate: String, Codable, Hashable, Sendable {
        case khz44_1 = "44.1"
        case khz48 = "48"
        case khz88_2 = "88.2"
        case khz96 = "96"
    }
}
