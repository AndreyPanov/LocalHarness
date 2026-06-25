import Foundation

extension Calendar {
    static func monthUTC(_ date: Date?) -> DateComponents? {
        guard let date else {
            return nil
        }

        return monthUTC(date)
    }

    static func monthUTC(_ date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        return calendar.dateComponents([.year, .month], from: date)
    }
}
