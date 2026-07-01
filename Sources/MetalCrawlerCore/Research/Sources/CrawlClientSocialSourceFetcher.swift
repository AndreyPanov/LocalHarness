import Foundation
import SocialSourceKit

struct CrawlClientSocialSourceFetcher: SocialSourceFetching {
    let crawlClient: any CrawlClient

    func fetch(_ request: SocialSourceRequest) async throws -> SocialSourcePage {
        let page = try await crawlClient.fetch(CrawlRequest(
            url: request.url,
            source: ResearchSource(rawValue: request.sourceKind ?? "social_source"),
            headers: request.headers
        ))

        return SocialSourcePage(
            url: page.url,
            finalURL: page.finalURL,
            text: page.text,
            html: page.html
        )
    }
}
