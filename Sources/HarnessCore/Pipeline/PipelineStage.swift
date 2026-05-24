import Foundation

protocol PipelineStage {
    associatedtype Input
    associatedtype Output
    
    func run(_ input: Input, context: PipelineContext) async throws -> Output
}

public struct PipelineContext: Sendable {
    public let runID: String
    public let month: Date
    public let runsDirectory: URL
    public let knowledgeDirectory: URL
    
    public var runDirectory: URL {
        runsDirectory.appendingPathComponent(runID, isDirectory: true)
    }
    
    public var seedFileURL: URL {
        knowledgeDirectory
            .appendingPathComponent("seeds", isDirectory: true)
            .appendingPathComponent("\(monthKey).json")
    }
    
    public var releaseKnowledgeURL: URL {
        knowledgeDirectory
            .appendingPathComponent("releases", isDirectory: true)
            .appendingPathComponent("\(monthKey).json")
    }
    
    public var monthKey: String {
        Self.monthKeyFormatter.string(from: month)
    }

    public var monthDisplayName: String {
        Self.monthDisplayFormatter.string(from: month)
    }

    public init(runID: String, month: Date, runsDirectory: URL, knowledgeDirectory: URL) {
        self.runID = runID
        self.month = month
        self.runsDirectory = runsDirectory
        self.knowledgeDirectory = knowledgeDirectory
    }

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let monthDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}
