import Foundation

public enum FileSystemJSONError: Error, Equatable {
    case invalidJSONFileName(String)
    case invalidEncodedData
    case invalidJSONPayload
}

/// Public interface for creating directories and reading/writing files.
public protocol FileSystemManaging: Sendable {
    /// System temporary directory.
    var temporaryDirectory: URL { get }

    /// Creates the directory, including any missing parent directories.
    func ensureDirectory(_ directory: URL) throws

    /// Creates a unique temporary directory under `temporaryDirectory/baseName`.
    func makeTemporaryDirectory(baseName: String) throws -> URL

    /// Returns true when a file or directory exists at the URL.
    func exists(_ url: URL) -> Bool

    /// Reads raw data from a file URL.
    func readData(from url: URL) throws -> Data

    /// Reads UTF-8 text from a file URL.
    func readText(from url: URL) throws -> String

    /// Writes raw data to a file URL, creating its parent directory first.
    func writeData(_ data: Data, to url: URL) throws

    /// Writes raw data to `directory/fileName`, creating the directory first.
    @discardableResult
    func writeData(_ data: Data, fileName: String, in directory: URL) throws -> URL

    /// Writes UTF-8 text to a file URL, creating its parent directory first.
    func writeText(_ text: String, to url: URL) throws

    /// Writes UTF-8 text to `directory/fileName`, creating the directory first.
    @discardableResult
    func writeText(_ text: String, fileName: String, in directory: URL) throws -> URL

    /// Reads and decodes JSON from a file URL.
    func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T

    /// Encodes JSON and writes it to a file URL, creating its parent directory first.
    func writeJSON<T: Encodable>(_ data: T, to url: URL) throws

    /// Encodes JSON and writes it to `directory/fileName`, creating the directory first.
    @discardableResult
    func writeJSON<T: Encodable>(_ data: T, fileName: String, in directory: URL) throws -> URL

    /// Formats an existing JSON payload and writes it to `directory/fileName`.
    @discardableResult
    func writePrettyJSONPayload(_ json: String, fileName: String, in directory: URL) throws -> URL

    /// Returns the URLs inside a directory.
    func contentsOfDirectory(at directory: URL) throws -> [URL]

    /// Removes a file or directory.
    func removeItem(at url: URL) throws
}
