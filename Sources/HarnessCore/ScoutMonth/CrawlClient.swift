import Foundation

protocol CrawlClient: Sendable {
    func fetch(_ request: CrawlRequest) async throws -> CrawledPage
}

struct CrawlRequest: Sendable {
    let url: URL
    let source: ResearchSource
}

struct CrawledPage: Sendable {
    let url: URL
    let finalURL: URL
    let title: String?
    let text: String
    let html: String?
}
