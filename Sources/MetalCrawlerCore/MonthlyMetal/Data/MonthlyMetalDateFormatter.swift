import Foundation

struct MonthlyMetalDateFormatter: Sendable {
    static let shared = MonthlyMetalDateFormatter()

    private init() {}

    func parse(_ rawValue: String) -> Date? {
        let value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"(\d+)(st|nd|rd|th)"#,
                with: "$1",
                options: .regularExpression
            )

        if let date = Self.formatter(dateFormat: "yyyy-MM-dd").date(from: value) {
            return date
        }

        if let date = Self.formatter(dateFormat: "MMMM d, yyyy").date(from: value) {
            return date
        }

        return nil
    }

    func format(_ date: Date) -> String {
        Self.formatter(dateFormat: "yyyy-MM-dd").string(from: date)
    }

    private static func formatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = dateFormat
        return formatter
    }
}
