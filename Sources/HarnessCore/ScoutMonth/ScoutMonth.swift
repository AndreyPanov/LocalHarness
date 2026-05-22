import Foundation

public struct ScoutMonth: Codable, Hashable, Sendable {
    public let rawValue: String
    public let year: Int
    public let month: Int
    
    public init(_ rawValue: String) throws {
        let parts = rawValue.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]), (1...12).contains(month) else {
            throw HarnessError.invalidMonth(rawValue)
        }
        self.rawValue = String(format: "%04d-%02d", year, month)
        self.year = year
        self.month = month
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
