import Foundation

/// A generated JSON payload paired with the file name it should be written to.
public struct JSONArtifact: Sendable {
    public let fileName: String
    public let contents: String

    public init(fileName: String, contents: String) {
        self.fileName = fileName
        self.contents = contents
    }
}

public enum JSONArtifactError: Error, Equatable {
    case invalidPattern(String)
    case invalidEncodedData
}

/// Public interface for turning typed data into formatted JSON strings.
public protocol JSONArtifactGenerating {
    /// Encodes `data` as formatted JSON after validating that `pattern` names a JSON file.
    func generateJSON<T: Encodable>(
        with pattern: String,
        data: T
    ) throws -> String

    /// Encodes `data` as JSON and pairs it with the target artifact file name.
    func generateArtifact<T: Encodable>(
        with pattern: String,
        data: T
    ) throws -> JSONArtifact
}

/// Public interface for writing JSON artifacts into a directory.
public protocol JSONArtifactWriting {
    /// Writes an already generated JSON artifact to `directory`.
    func write(
        _ artifact: JSONArtifact,
        to directory: URL
    ) -> Bool

    /// Writes a JSON string to `directory/fileName`.
    func write(
        to directory: URL,
        fileName: String,
        data: String
    ) -> Bool

    /// Writes a JSON string to a default file name in `directory`.
    func write(
        to directory: URL,
        data: String
    ) -> Bool
}

/// Combined interface for callers that both generate and persist JSON artifacts.
public typealias JSONArtifactHandling = JSONArtifactGenerating & JSONArtifactWriting
