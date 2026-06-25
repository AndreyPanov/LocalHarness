import Foundation

struct EditorialSourceDescriptor: Decodable, Hashable, Sendable {
    let name: String
    let kind: String
    let sourceURL: URL?
    let file: String?
    let channelID: String?
    let username: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case kind
        case sourceURL
        case url
        case file
        case channelID
        case username
    }

    init(
        name: String,
        kind: String,
        sourceURL: URL?,
        file: String? = nil,
        channelID: String? = nil,
        username: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.sourceURL = sourceURL
        self.file = file
        self.channelID = channelID
        self.username = username
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
            ?? container.decodeIfPresent(URL.self, forKey: .url)
        self.file = try container.decodeIfPresent(String.self, forKey: .file)
        self.channelID = try container.decodeIfPresent(String.self, forKey: .channelID)
        self.username = try container.decodeIfPresent(String.self, forKey: .username)
    }
}

struct EditorialSourceManifest: Decodable, Sendable {
    let sources: [EditorialSourceDescriptor]

    private enum CodingKeys: CodingKey {
        case sources
    }

    init(from decoder: Decoder) throws {
        if let sources = try? [EditorialSourceDescriptor](from: decoder) {
            self.sources = sources
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sources = try container.decode([EditorialSourceDescriptor].self, forKey: .sources)
    }
}

struct EditorialSourceDocumentSource: Sendable {
    private let knowledgeDirectory: URL
    private let bangerTVSource: BangerTVEditorialDocumentSource
    private let instagramSource: InstagramProfileEditorialDocumentSource

    init(
        knowledgeDirectory: URL,
        bangerTVSource: BangerTVEditorialDocumentSource = BangerTVEditorialDocumentSource(),
        instagramSource: InstagramProfileEditorialDocumentSource = InstagramProfileEditorialDocumentSource()
    ) {
        self.knowledgeDirectory = knowledgeDirectory
        self.bangerTVSource = bangerTVSource
        self.instagramSource = instagramSource
    }

    func documents(
        for month: Date,
        context: ResearchContext
    ) async throws -> [MonthlyMetalEditorialSourceDocument] {
        let sourceManifests = try sourceManifests(for: month)

        var documents: [MonthlyMetalEditorialSourceDocument] = []

        for sourceManifest in sourceManifests {
            let descriptor = sourceManifest.descriptor

            if let file = descriptor.file {
                documents.append(try fileDocument(
                    descriptor: descriptor,
                    directory: sourceManifest.directory,
                    file: file
                ))
                continue
            }

            switch descriptor.kind {
            case "youtube_channel":
                documents.append(contentsOf: try await bangerTVSource.documents(
                    for: month,
                    descriptor: descriptor,
                    context: context
                ))

            case "instagram_profile":
                documents.append(contentsOf: try await instagramSource.documents(
                    for: month,
                    descriptor: descriptor,
                    context: context
                ))

            default:
                continue
            }
        }

        return deduplicated(documents)
    }

    func globalSourceDirectory() -> URL {
        knowledgeDirectory
            .appendingPathComponent("editorial-sources", isDirectory: true)
    }

    func sourceDirectory(for month: Date) -> URL {
        globalSourceDirectory()
            .appendingPathComponent(monthPathComponent(for: month), isDirectory: true)
    }

    private func sourceManifests(for month: Date) throws -> [EditorialSourceManifestEntry] {
        let globalDirectory = globalSourceDirectory()
        let monthDirectory = sourceDirectory(for: month)
        let manifestLocations = [
            globalDirectory,
            monthDirectory
        ]

        return try manifestLocations.flatMap { directory in
            let manifestURL = directory.appendingPathComponent("sources.json", isDirectory: false)

            guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                return [EditorialSourceManifestEntry]()
            }

            let manifest = try JSONDecoder().decode(
                EditorialSourceManifest.self,
                from: Data(contentsOf: manifestURL)
            )

            return manifest.sources.map {
                EditorialSourceManifestEntry(
                    descriptor: $0,
                    directory: directory
                )
            }
        }
    }

    private func fileDocument(
        descriptor: EditorialSourceDescriptor,
        directory: URL,
        file: String
    ) throws -> MonthlyMetalEditorialSourceDocument {
        let sourceFileURL = directory.appendingPathComponent(file, isDirectory: false)
        let text = try String(contentsOf: sourceFileURL, encoding: .utf8)

        return MonthlyMetalEditorialSourceDocument(
            sourceName: descriptor.name,
            sourceKind: descriptor.kind,
            sourceURL: descriptor.sourceURL,
            itemURL: sourceFileURL,
            title: descriptor.name,
            publishedAt: nil,
            text: text
        )
    }

    private func monthPathComponent(for month: Date) -> String {
        let components = Calendar.monthUTC(month)
        return String(format: "%04d-%02d", components.year!, components.month!)
    }

    private func deduplicated(
        _ documents: [MonthlyMetalEditorialSourceDocument]
    ) -> [MonthlyMetalEditorialSourceDocument] {
        var seen = Set<URL>()
        var result: [MonthlyMetalEditorialSourceDocument] = []

        for document in documents {
            guard let itemURL = document.itemURL else {
                result.append(document)
                continue
            }

            guard !seen.contains(itemURL) else {
                continue
            }

            seen.insert(itemURL)
            result.append(document)
        }

        return result
    }
}

private struct EditorialSourceManifestEntry: Sendable {
    let descriptor: EditorialSourceDescriptor
    let directory: URL
}
