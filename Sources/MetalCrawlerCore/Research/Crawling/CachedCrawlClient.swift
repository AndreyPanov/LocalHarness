import Foundation
import CryptoKit
import FileSystemKit

final class CachedCrawlClient: CrawlClient {
    private let wrapped: any CrawlClient
    private let cacheDirectory: URL
    private let fileSystem: any FileSystemManaging

    init(
        wrapped: any CrawlClient,
        cacheDirectory: URL,
        fileSystem: any FileSystemManaging = FileSystem.shared
    ) {
        self.wrapped = wrapped
        self.cacheDirectory = cacheDirectory
        self.fileSystem = fileSystem
    }

    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        try fileSystem.ensureDirectory(cacheDirectory)

        let cacheURL = cacheDirectory.appendingPathComponent(cacheKey(for: request) + ".json")

        if fileSystem.exists(cacheURL) {
            let data = try fileSystem.readData(from: cacheURL)
            return try JSONDecoder().decode(CrawledPage.self, from: data)
        }

        let page = try await wrapped.fetch(request)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(page)
        try fileSystem.writeData(data, to: cacheURL)

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
