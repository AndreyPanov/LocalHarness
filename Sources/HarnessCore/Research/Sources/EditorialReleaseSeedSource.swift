import Foundation

struct EditorialReleaseSeed: Hashable, Sendable {
    let bandName: String
    let albumTitle: String
    let releaseDate: Date?
    let releaseDateText: String?
    let labelName: String?
    let source: MonthlyMetalCandidateSource
}

struct EditorialReleaseSourceDescriptor: Decodable, Hashable, Sendable {
    let name: String
    let kind: String
    let sourceURL: URL?
    let file: String

    private enum CodingKeys: String, CodingKey {
        case name
        case kind
        case sourceURL
        case url
        case file
    }

    init(name: String, kind: String, sourceURL: URL?, file: String) {
        self.name = name
        self.kind = kind
        self.sourceURL = sourceURL
        self.file = file
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.name = try container.decode(String.self, forKey: .name)
        self.kind = try container.decode(String.self, forKey: .kind)
        self.sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
            ?? container.decodeIfPresent(URL.self, forKey: .url)
        self.file = try container.decode(String.self, forKey: .file)
    }
}

struct EditorialReleaseSourceManifest: Decodable, Sendable {
    let sources: [EditorialReleaseSourceDescriptor]

    private enum CodingKeys: CodingKey {
        case sources
    }

    init(from decoder: Decoder) throws {
        if let sources = try? [EditorialReleaseSourceDescriptor](from: decoder) {
            self.sources = sources
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sources = try container.decode([EditorialReleaseSourceDescriptor].self, forKey: .sources)
    }
}

struct EditorialReleaseSeedSource: Sendable {
    private let knowledgeDirectory: URL
    private let parser: EditorialReleaseDescriptionParser

    init(
        knowledgeDirectory: URL,
        parser: EditorialReleaseDescriptionParser = EditorialReleaseDescriptionParser()
    ) {
        self.knowledgeDirectory = knowledgeDirectory
        self.parser = parser
    }

    func seeds(for month: Date) throws -> [EditorialReleaseSeed] {
        let directory = sourceDirectory(for: month)
        let manifestURL = directory.appendingPathComponent("sources.json", isDirectory: false)

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return []
        }

        let manifest = try JSONDecoder().decode(
            EditorialReleaseSourceManifest.self,
            from: Data(contentsOf: manifestURL)
        )

        var seeds: [EditorialReleaseSeed] = []

        for descriptor in manifest.sources {
            let sourceFileURL = directory.appendingPathComponent(descriptor.file, isDirectory: false)
            let description = try String(contentsOf: sourceFileURL, encoding: .utf8)
            seeds.append(contentsOf: parser.seeds(from: description, descriptor: descriptor))
        }

        return deduplicated(seeds)
    }

    func sourceDirectory(for month: Date) -> URL {
        knowledgeDirectory
            .appendingPathComponent("editorial-sources", isDirectory: true)
            .appendingPathComponent(monthPathComponent(for: month), isDirectory: true)
    }

    private func monthPathComponent(for month: Date) -> String {
        let components = Calendar.monthUTC(month)
        return String(format: "%04d-%02d", components.year!, components.month!)
    }

    private func deduplicated(_ seeds: [EditorialReleaseSeed]) -> [EditorialReleaseSeed] {
        var seen = Set<MonthlyMetalReleaseIdentity>()
        var result: [EditorialReleaseSeed] = []

        for seed in seeds {
            let identity = MonthlyMetalReleaseIdentity(
                bandName: seed.bandName,
                albumTitle: seed.albumTitle
            )

            guard !seen.contains(identity) else {
                continue
            }

            seen.insert(identity)
            result.append(seed)
        }

        return result
    }
}

struct EditorialReleaseDescriptionParser: Sendable {
    func seeds(
        from description: String,
        descriptor: EditorialReleaseSourceDescriptor
    ) -> [EditorialReleaseSeed] {
        deduplicated(
            blockSeeds(from: description, descriptor: descriptor)
                + rankedLineSeeds(from: description, descriptor: descriptor)
        )
    }

    private func blockSeeds(
        from description: String,
        descriptor: EditorialReleaseSourceDescriptor
    ) -> [EditorialReleaseSeed] {
        let blocks = descriptionBlocks(from: description)
        var seeds: [EditorialReleaseSeed] = []

        for block in blocks {
            guard let seed = seed(fromBlock: block, descriptor: descriptor, rank: seeds.count + 1) else {
                continue
            }

            seeds.append(seed)
        }

        return seeds
    }

    private func seed(
        fromBlock lines: [String],
        descriptor: EditorialReleaseSourceDescriptor,
        rank: Int
    ) -> EditorialReleaseSeed? {
        guard let itemURL = lines.compactMap(firstURL).first,
              let dateLineIndex = lines.firstIndex(where: { MonthlyMetalDateFormatter.shared.parse($0) != nil }),
              dateLineIndex >= 2
        else {
            return nil
        }

        let bandName = cleanReleaseText(lines[0])
        let albumTitle = cleanReleaseText(lines[1])

        guard isReleaseName(bandName),
              isReleaseName(albumTitle)
        else {
            return nil
        }

        let releaseDateText = cleanReleaseText(lines[dateLineIndex])
        let labelName = labelName(from: lines, dateLineIndex: dateLineIndex)

        return EditorialReleaseSeed(
            bandName: bandName,
            albumTitle: albumTitle,
            releaseDate: MonthlyMetalDateFormatter.shared.parse(releaseDateText),
            releaseDateText: releaseDateText,
            labelName: labelName,
            source: MonthlyMetalCandidateSource(
                name: descriptor.name,
                kind: descriptor.kind,
                sourceURL: descriptor.sourceURL,
                itemURL: itemURL,
                rank: rank,
                note: labelName.map { "Label: \($0)" }
            )
        )
    }

    private func rankedLineSeeds(
        from description: String,
        descriptor: EditorialReleaseSourceDescriptor
    ) -> [EditorialReleaseSeed] {
        normalizedLines(from: description).compactMap { line in
            seed(fromRankedLine: line, descriptor: descriptor)
        }
        .enumerated()
        .map { offset, seed in
            EditorialReleaseSeed(
                bandName: seed.bandName,
                albumTitle: seed.albumTitle,
                releaseDate: seed.releaseDate,
                releaseDateText: seed.releaseDateText,
                labelName: seed.labelName,
                source: MonthlyMetalCandidateSource(
                    name: seed.source.name,
                    kind: seed.source.kind,
                    sourceURL: seed.source.sourceURL,
                    itemURL: seed.source.itemURL,
                    rank: offset + 1,
                    note: seed.source.note
                )
            )
        }
    }

    private func seed(
        fromRankedLine line: String,
        descriptor: EditorialReleaseSourceDescriptor
    ) -> EditorialReleaseSeed? {
        let itemURL = firstURL(in: line)
        let lineWithoutURL = line
            .replacingOccurrences(of: #"https?://\S+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let match = firstMatch(
            in: lineWithoutURL,
            pattern: #"^\s*(?:[#*\-]\s*)?(?:\d{1,3}\s*[\.)]\s*)?(.+?)\s+(?:-|–|—|:)\s+(.+?)\s*$"#
        ) else {
            return nil
        }

        let bandName = cleanReleaseText(match.0)
        let albumTitle = cleanReleaseText(match.1)

        guard isReleaseName(bandName),
              isReleaseName(albumTitle)
        else {
            return nil
        }

        return EditorialReleaseSeed(
            bandName: bandName,
            albumTitle: albumTitle,
            releaseDate: nil,
            releaseDateText: nil,
            labelName: nil,
            source: MonthlyMetalCandidateSource(
                name: descriptor.name,
                kind: descriptor.kind,
                sourceURL: descriptor.sourceURL,
                itemURL: itemURL,
                note: nil
            )
        )
    }

    private func descriptionBlocks(from description: String) -> [[String]] {
        var blocks: [[String]] = []
        var currentBlock: [String] = []

        for line in normalizedLines(from: description) {
            if line.isEmpty {
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock)
                    currentBlock = []
                }
            } else {
                currentBlock.append(line)
            }
        }

        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        return blocks
    }

    private func normalizedLines(from description: String) -> [String] {
        description
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func labelName(from lines: [String], dateLineIndex: Int) -> String? {
        guard dateLineIndex > 2 else {
            return nil
        }

        let labels = lines[2..<dateLineIndex]
            .map(cleanReleaseText)
            .filter(isReleaseName)

        guard !labels.isEmpty else {
            return nil
        }

        return labels.joined(separator: " / ")
    }

    private func firstURL(in value: String) -> URL? {
        guard let rawURL = firstMatch(in: value, pattern: #"(https?://[^\s<>)\]]+)"#)?.0 else {
            return nil
        }

        return URL(string: rawURL.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:")))
    }

    private func firstMatch(in value: String, pattern: String) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)

        guard let match = regex.firstMatch(in: value, range: range),
              match.numberOfRanges > 1,
              let firstRange = Range(match.range(at: 1), in: value)
        else {
            return nil
        }

        let second: String

        if match.numberOfRanges > 2,
           let secondRange = Range(match.range(at: 2), in: value)
        {
            second = String(value[secondRange])
        } else {
            second = ""
        }

        return (String(value[firstRange]), second)
    }

    private func cleanReleaseText(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"^\s*["'“”‘’]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"["'“”‘’]+\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\[|\]\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isReleaseName(_ value: String) -> Bool {
        guard value.count >= 2 else {
            return false
        }

        let lowercased = value.lowercased()
        let excludedPrefixes = [
            "http",
            "join ",
            "subscribe",
            "buy ",
            "sign up",
            "like us",
            "follow us",
            "#",
            "0:"
        ]

        return !excludedPrefixes.contains { lowercased.hasPrefix($0) }
    }

    private func deduplicated(_ seeds: [EditorialReleaseSeed]) -> [EditorialReleaseSeed] {
        var seen = Set<MonthlyMetalReleaseIdentity>()
        var result: [EditorialReleaseSeed] = []

        for seed in seeds {
            let identity = MonthlyMetalReleaseIdentity(
                bandName: seed.bandName,
                albumTitle: seed.albumTitle
            )

            guard !seen.contains(identity) else {
                continue
            }

            seen.insert(identity)
            result.append(seed)
        }

        return result
    }
}
