import Foundation

public struct RunID: Codable, Hashable, Sendable {
    public let rawValue: String
    
    public init(_ rawValue: String = UUID().uuidString) {
        self.rawValue = rawValue
    }
}
