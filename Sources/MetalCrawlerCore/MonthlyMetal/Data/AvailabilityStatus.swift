public enum AvailabilityStatus: String, Codable, Sendable {
    case available
    case notFound = "not_found"
    case unknown
}
