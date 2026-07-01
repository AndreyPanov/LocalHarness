import Foundation

public struct JSONArtifactGenerator: JSONArtifactHandling {
    private let encoder: JSONEncoder

    public init(
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601,
        outputFormatting: JSONEncoder.OutputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    ) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = dateEncodingStrategy
        encoder.outputFormatting = outputFormatting
        self.encoder = encoder
    }

    public func generateJSON<T: Encodable>(
        with pattern: String,
        data: T
    ) throws -> String {
        guard pattern.hasSuffix(".json"), !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JSONArtifactError.invalidPattern(pattern)
        }

        let encoded = try encoder.encode(data)

        guard let json = String(data: encoded, encoding: .utf8) else {
            throw JSONArtifactError.invalidEncodedData
        }

        return json
    }

    public func generateArtifact<T: Encodable>(
        with pattern: String,
        data: T
    ) throws -> JSONArtifact {
        JSONArtifact(
            fileName: pattern,
            contents: try generateJSON(with: pattern, data: data)
        )
    }

    public func write(
        _ artifact: JSONArtifact,
        to directory: URL
    ) -> Bool {
        write(
            to: directory,
            fileName: artifact.fileName,
            data: artifact.contents
        )
    }

    public func write(
        to directory: URL,
        fileName: String,
        data: String
    ) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try data.write(
                to: directory.appendingPathComponent(fileName, isDirectory: false),
                atomically: true,
                encoding: .utf8
            )
            return true
        } catch {
            return false
        }
    }

    public func write(
        to directory: URL,
        data: String
    ) -> Bool {
        write(to: directory, fileName: "output.json", data: data)
    }
}

public func generateJSON<T: Encodable>(
    with pattern: String,
    data: T
) throws -> String {
    try JSONArtifactGenerator().generateJSON(with: pattern, data: data)
}

public func write(
    to directory: URL,
    data: String
) -> Bool {
    JSONArtifactGenerator().write(to: directory, data: data)
}
