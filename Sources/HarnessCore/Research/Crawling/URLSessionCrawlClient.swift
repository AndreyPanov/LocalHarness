import Foundation

final class URLSessionCrawlClient: CrawlClient {
    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        var urlRequest = URLRequest(url: request.url)

        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
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
            title: HTMLTextExtractor.shared.title(from: html),
            text: HTMLTextExtractor.shared.visibleText(from: html),
            html: html
        )
    }
}
