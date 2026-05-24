import Foundation

protocol PipelineStage {
    associatedtype Input
    associatedtype Output
    
    func run(_ input: Input, context: PipelineContext) async throws -> Output
}

public struct PipelineContext: Sendable {
    public let runID: String
    public let month: ReleaseMonth
    public let runsDirectory: URL
    public let knowledgeDirectory: URL
    
    public var runDirectory: URL {
        runsDirectory.appendingPathComponent(runID, isDirectory: true)
    }
    
    public var seedFileURL: URL {
        knowledgeDirectory
            .appendingPathComponent("seeds", isDirectory: true)
            .appendingPathComponent("\(month.rawValue).json")
    }
    
    public var releaseKnowledgeURL: URL {
        knowledgeDirectory
            .appendingPathComponent("releases", isDirectory: true)
            .appendingPathComponent("\(month.rawValue).json")
    }
    
    public init(runID: String, month: ReleaseMonth, runsDirectory: URL, knowledgeDirectory: URL) {
        self.runID = runID
        self.month = month
        self.runsDirectory = runsDirectory
        self.knowledgeDirectory = knowledgeDirectory
    }
}
