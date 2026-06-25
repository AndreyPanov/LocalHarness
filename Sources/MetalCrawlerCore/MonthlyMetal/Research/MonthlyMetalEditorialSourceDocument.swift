import Foundation

public struct MonthlyMetalEditorialSourceDocument: Codable, Hashable, Sendable {
    public let sourceName: String
    public let sourceKind: String
    public let sourceURL: URL?
    public let itemURL: URL?
    public let title: String?
    public let publishedAt: Date?
    public let text: String

    public init(
        sourceName: String,
        sourceKind: String,
        sourceURL: URL?,
        itemURL: URL?,
        title: String?,
        publishedAt: Date?,
        text: String
    ) {
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.sourceURL = sourceURL
        self.itemURL = itemURL
        self.title = title
        self.publishedAt = publishedAt
        self.text = text
    }
}
