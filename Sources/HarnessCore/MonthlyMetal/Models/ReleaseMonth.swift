import Foundation

public struct ReleaseMonth: Codable, Hashable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) throws {
            guard (1...12).contains(month) else {
                throw HarnessError.invalidMonth("\(year)-\(month)")
            }

            self.year = year
            self.month = month
        }

        public init(_ rawValue: String) throws {
            let parts = rawValue.split(separator: "-")

            guard parts.count == 2,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]),
                  (1...12).contains(month)
            else {
                throw HarnessError.invalidMonth(rawValue)
            }

            self.year = year
            self.month = month
        }

    public var rawValue: String {
        String(format: "%04d-%02d", year, month)
    }
    
    public var description: String {
        rawValue
    }

    public var displayName: String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        let date = Calendar(identifier: .gregorian).date(from: components) ?? Date()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL yyyy"

        return formatter.string(from: date)
    }
}
