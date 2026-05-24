import Foundation

final class URLSessionCrawlClient: CrawlClient {
    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        let (data, response) = try await URLSession.shared.data(from: request.url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HarnessError.invalidCrawlResponse(request.url.absoluteString)
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HarnessError.crawlRequestFailed(
                url: request.url.absoluteString,
                statusCode: httpResponse.statusCode
            )
        }
        
        let html = String(decoding: data, as: UTF8.self)
        
        return CrawledPage(
            url: request.url,
            finalURL: httpResponse.url ?? request.url,
            title: HTMLTextExtractor.title(from: html),
            text: HTMLTextExtractor.visibleText(from: html),
            html: html
        )
    }
}
