import Foundation

public struct FileSystem: FileSystemManaging {
    public static let shared = FileSystem()

    public init() {}

    public var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    public func ensureDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    public func makeTemporaryDirectory(baseName: String) throws -> URL {
        let url = temporaryDirectory
            .appendingPathComponent(baseName, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try ensureDirectory(url)
        return url
    }

    public func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func readData(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func readText(from url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    public func writeData(_ data: Data, to url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
    }

    @discardableResult
    public func writeData(
        _ data: Data,
        fileName: String,
        in directory: URL
    ) throws -> URL {
        try ensureDirectory(directory)
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return url
    }

    public func writeText(_ text: String, to url: URL) throws {
        try ensureDirectory(url.deletingLastPathComponent())
        try text.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
    }

    @discardableResult
    public func writeText(
        _ text: String,
        fileName: String,
        in directory: URL
    ) throws -> URL {
        try ensureDirectory(directory)
        let url = directory.appendingPathComponent(fileName, isDirectory: false)
        try text.write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        return url
    }

    public func readJSON<T: Decodable>(
        _ type: T.Type,
        from url: URL
    ) throws -> T {
        try JSONDecoder().decode(type, from: readData(from: url))
    }

    public func writeJSON<T: Encodable>(_ data: T, to url: URL) throws {
        try validateJSONFileName(url.lastPathComponent)
        try writeData(try encodedJSON(data), to: url)
    }

    @discardableResult
    public func writeJSON<T: Encodable>(
        _ data: T,
        fileName: String,
        in directory: URL
    ) throws -> URL {
        try validateJSONFileName(fileName)
        return try writeData(try encodedJSON(data), fileName: fileName, in: directory)
    }

    @discardableResult
    public func writePrettyJSONPayload(
        _ json: String,
        fileName: String,
        in directory: URL
    ) throws -> URL {
        try validateJSONFileName(fileName)

        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object)
        else {
            throw FileSystemJSONError.invalidJSONPayload
        }

        let prettyData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )

        guard let prettyJSON = String(data: prettyData, encoding: .utf8) else {
            throw FileSystemJSONError.invalidEncodedData
        }

        return try writeText(prettyJSON, fileName: fileName, in: directory)
    }

    public func contentsOfDirectory(at directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
    }

    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    private func encodedJSON<T: Encodable>(_ data: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(data)
    }

    private func validateJSONFileName(_ fileName: String) throws {
        guard fileName.hasSuffix(".json"),
              !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw FileSystemJSONError.invalidJSONFileName(fileName)
        }
    }
}
