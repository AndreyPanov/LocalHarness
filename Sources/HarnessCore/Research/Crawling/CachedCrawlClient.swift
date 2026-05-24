final class CachedCrawlClient: CrawlClient {
    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        throw HarnessError.crawlClientNotImplemented("cached")
    }
}
