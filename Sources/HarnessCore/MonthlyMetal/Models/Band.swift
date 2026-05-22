import Foundation

public struct Band: Codable, Hashable, Sendable {
    public let id: BandID
    public let name: String
    public let country: CountryName?
    public let formedIn: Year?
    public let history: String?

    public init(id: BandID, name: String, country: CountryName? = nil, formedIn: Year? = nil, history: String? = nil) {
        self.id = id
        self.name = name
        self.country = country
        self.formedIn = formedIn
        self.history = history
    }
}
