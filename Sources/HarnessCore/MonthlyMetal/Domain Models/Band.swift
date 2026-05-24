import Foundation

public struct Band: Codable, Hashable, Sendable {
    public let id: BandID
    public let name: String
    public let country: String?
    public let formedIn: Date?
    public let history: String?

    public init(id: BandID, name: String, country: String? = nil, formedIn: Date? = nil, history: String? = nil) {
        self.id = id
        self.name = name
        self.country = country
        self.formedIn = formedIn
        self.history = history
    }
}

public struct BandID: Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String
    
    public init(_ rawValue: String = UUID().uuidString) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
