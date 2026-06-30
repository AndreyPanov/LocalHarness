import Foundation

struct CrawlSourceDescriptor: Decodable, Hashable, Sendable {
    let name: String
    let kind: String
    let sourceURL: URL?
    let channelID: String?
    let username: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case kind
        case sourceURL
        case url
        case channelID
        case username
    }

    init(
        name: String,
        kind: String,
        sourceURL: URL?,
        channelID: String? = nil,
        username: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.sourceURL = sourceURL
        self.channelID = channelID
        self.username = username
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
            ?? container.decodeIfPresent(URL.self, forKey: .url)
        self.channelID = try container.decodeIfPresent(String.self, forKey: .channelID)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
    }
}

struct CrawlSourceManifest: Decodable, Sendable {
    let sources: [CrawlSourceDescriptor]

    private enum CodingKeys: CodingKey {
        case sources
    }

    init(from decoder: Decoder) throws {
        if let sources = try? [CrawlSourceDescriptor](from: decoder) {
            self.sources = sources
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sources = try container.decode([CrawlSourceDescriptor].self, forKey: .sources)
    }
}

struct CrawlSourceItemProvider: Sendable {
    private let knowledgeDirectory: URL
    private let bangerTVSource: BangerTVSourceItemProvider
    private let instagramSource: InstagramProfileSourceItemProvider

    init(
        knowledgeDirectory: URL,
        bangerTVSource: BangerTVSourceItemProvider = BangerTVSourceItemProvider(),
        instagramSource: InstagramProfileSourceItemProvider = InstagramProfileSourceItemProvider()
    ) {
        self.knowledgeDirectory = knowledgeDirectory
        self.bangerTVSource = bangerTVSource
        self.instagramSource = instagramSource
    }

    func sourceItems(
        for month: Date,
        context: ResearchContext
    ) async throws -> [MonthlyMetalSourceItem] {
        let sourceManifests = try sourceManifests(for: month)

        var sourceItems: [MonthlyMetalSourceItem] = []

        for sourceManifest in sourceManifests {
            let descriptor = sourceManifest.descriptor

            switch descriptor.kind {
            case "youtube_channel":
                sourceItems.append(contentsOf: try await bangerTVSource.sourceItems(
                    for: month,
                    descriptor: descriptor,
                    context: context
                ))

            case "instagram_profile":
                sourceItems.append(contentsOf: try await instagramSource.sourceItems(
                    for: month,
                    descriptor: descriptor,
                    context: context
                ))

            default:
                continue
            }
        }

        return deduplicated(sourceItems)
    }

    func globalSourceDirectory() -> URL {
        knowledgeDirectory
            .appendingPathComponent("crawl-sources", isDirectory: true)
    }

    func sourceDirectory(for month: Date) -> URL {
        globalSourceDirectory()
            .appendingPathComponent(monthPathComponent(for: month), isDirectory: true)
    }

    private func sourceManifests(for month: Date) throws -> [CrawlSourceManifestEntry] {
        let globalDirectory = globalSourceDirectory()
        let monthDirectory = sourceDirectory(for: month)
        let manifestLocations = [
            globalDirectory,
            monthDirectory
        ]

        return try manifestLocations.flatMap { directory in
            let manifestURL = directory.appendingPathComponent("sources.json", isDirectory: false)

            guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                return [CrawlSourceManifestEntry]()
            }

            let manifest = try JSONDecoder().decode(
                CrawlSourceManifest.self,
                from: Data(contentsOf: manifestURL)
            )

            return manifest.sources.map {
                CrawlSourceManifestEntry(
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
}

private struct CrawlSourceManifestEntry: Sendable {
    let descriptor: CrawlSourceDescriptor
    let directory: URL
}
