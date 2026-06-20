import Foundation

protocol CrawlClient: Sendable {
    func fetch(_ request: CrawlRequest) async throws -> CrawledPage
}

struct CrawlRequest: Sendable {
    let url: URL
    let source: ResearchSource
    let headers: [String: String]

    init(url: URL, source: ResearchSource, headers: [String: String] = [:]) {
        self.url = url
        self.source = source
        self.headers = headers
    }
}

struct ResearchSource: Hashable, Sendable {
    let rawValue: String
}

struct CrawledPage: Sendable, Codable {
    let url: URL
    let finalURL: URL
    let title: String?
    let text: String
    let html: String?
}
