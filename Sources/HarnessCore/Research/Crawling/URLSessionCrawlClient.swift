final class URLSessionCrawlClient: CrawlClient {
    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        throw HarnessError.crawlClientNotImplemented("url_session")
    }
}
