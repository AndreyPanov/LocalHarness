public enum ReleaseFormat: Codable, Sendable {
    case digital(DigitalAudioResolution)
    case cd
    case vinyl
    case cassette
    case unknown
}
