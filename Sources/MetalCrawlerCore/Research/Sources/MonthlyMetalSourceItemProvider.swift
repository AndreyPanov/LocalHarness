import Foundation
import FileSystemKit
import SocialSourceKit

struct MonthlyMetalSourceManifest: Decodable, Sendable {
    let sources: [SourceProviderDescriptor]

    private enum CodingKeys: CodingKey {
        case sources
    }

    init(from decoder: Decoder) throws {
        if let sources = try? [SourceProviderDescriptor](from: decoder) {
            self.sources = sources
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sources = try container.decode([SourceProviderDescriptor].self, forKey: .sources)
    }
}

struct MonthlyMetalSourceItemProvider: Sendable {
    private let knowledgeDirectory: URL
    private let sourceDataProviderFactory: @Sendable (any CrawlClient) -> any SourceDataProviding
    private let fileSystem: any FileSystemManaging

    init(
        knowledgeDirectory: URL,
        sourceDataProviderFactory: @escaping @Sendable (any CrawlClient) -> any SourceDataProviding = { crawlClient in
            SourceDataClient(
                fetcher: CrawlClientSocialSourceFetcher(crawlClient: crawlClient)
            )
        },
        fileSystem: any FileSystemManaging = FileSystem.shared
    ) {
        self.knowledgeDirectory = knowledgeDirectory
        self.sourceDataProviderFactory = sourceDataProviderFactory
        self.fileSystem = fileSystem
    }

    func sourceItems(for month: Date, context: ResearchContext) async throws -> [MonthlyMetalSourceItem] {
        let sourceManifests = try sourceManifests(for: month)
        let sourceDataProvider = sourceDataProviderFactory(context.crawlClient)

        var sourceItems: [MonthlyMetalSourceItem] = []

        for sourceManifest in sourceManifests {
            sourceItems.append(contentsOf: try await sourceDataProvider.sourceItems(
                for: month,
                descriptor: sourceManifest.descriptor
            ).map { monthlyMetalSourceItem(from: $0) })
        }

        return deduplicated(sourceItems)
    }

    func globalSourceDirectory() -> URL {
        knowledgeDirectory
            .appendingPathComponent("source-providers", isDirectory: true)
    }

    func sourceDirectory(for month: Date) -> URL {
        globalSourceDirectory()
            .appendingPathComponent(monthPathComponent(for: month), isDirectory: true)
    }

    private func sourceManifests(for month: Date) throws -> [MonthlyMetalSourceManifestEntry] {
        let globalDirectory = globalSourceDirectory()
        let monthDirectory = sourceDirectory(for: month)
        let manifestLocations = [
            globalDirectory,
            monthDirectory
        ]

        return try manifestLocations.flatMap { directory in
            let manifestURL = directory.appendingPathComponent("sources.json", isDirectory: false)

            guard fileSystem.exists(manifestURL) else {
                return [MonthlyMetalSourceManifestEntry]()
            }

            let manifest = try JSONDecoder().decode(
                MonthlyMetalSourceManifest.self,
                from: fileSystem.readData(from: manifestURL)
            )

            return manifest.sources.filter(\.enabled).map {
                MonthlyMetalSourceManifestEntry(
                    descriptor: $0,
                    directory: directory
                )
            }
        }
    }

    private func monthPathComponent(for month: Date) -> String {
        let components = Calendar.monthUTC(month)
        return String(format: "%04d-%02d", components.year!, components.month!)
    }

    private func deduplicated(
        _ sourceItems: [MonthlyMetalSourceItem]
    ) -> [MonthlyMetalSourceItem] {
        var seen = Set<URL>()
        var result: [MonthlyMetalSourceItem] = []

        for sourceItem in sourceItems {
            guard let itemURL = sourceItem.itemURL else {
                result.append(sourceItem)
                continue
            }

            guard !seen.contains(itemURL) else {
                continue
            }

            seen.insert(itemURL)
            result.append(sourceItem)
        }

        return result
    }

    private func monthlyMetalSourceItem(
        from item: SourceProviderItem
    ) -> MonthlyMetalSourceItem {
        MonthlyMetalSourceItem(
            sourceName: item.sourceName,
            sourceKind: item.sourceKind,
            sourceURL: item.sourceURL,
            itemURL: item.itemURL,
            title: item.title,
            publishedAt: item.publishedAt,
            text: item.text
        )
    }
}

private struct MonthlyMetalSourceManifestEntry: Sendable {
    let descriptor: SourceProviderDescriptor
    let directory: URL
}
