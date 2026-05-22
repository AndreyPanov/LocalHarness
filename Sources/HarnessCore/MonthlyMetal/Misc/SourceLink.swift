import Foundation

public struct SourceLink: Codable, Hashable, Sendable {
    public let source: String
    public let url: URL

    public init(source: String, url: URL) {
        self.source = source
        self.url = url
    }
}
