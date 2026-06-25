import Foundation
import CryptoKit

final class CachedCrawlClient: CrawlClient {
    private let wrapped: any CrawlClient
    private let cacheDirectory: URL

    init(wrapped: any CrawlClient, cacheDirectory: URL) {
        self.wrapped = wrapped
        self.cacheDirectory = cacheDirectory
    }

    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        try FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        let cacheURL = cacheDirectory.appendingPathComponent(cacheKey(for: request) + ".json")

        if FileManager.default.fileExists(atPath: cacheURL.path) {
            let data = try Data(contentsOf: cacheURL)
            return try JSONDecoder().decode(CrawledPage.self, from: data)
        }

        let page = try await wrapped.fetch(request)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(page)
        try data.write(to: cacheURL, options: .atomic)

        return page
    }

    private func cacheKey(for request: CrawlRequest) -> String {
        let headers = request.headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
        let value = "\(request.source.rawValue)\n\(request.url.absoluteString)\n\(headers)"

        return SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
