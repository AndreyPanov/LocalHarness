import Foundation

public struct ReleaseMonth: Codable, Hashable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        precondition((1...12).contains(month), "ReleaseMonth month must be between 1 and 12.")
        self.year = year
        self.month = month
    }

    public var rawValue: String {
        String(format: "%04d-%02d", year, month)
    }
}
