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

    public func contentsOfDirectory(at directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
    }

    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
