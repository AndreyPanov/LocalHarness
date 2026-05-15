public protocol ModelGateway: Sendable {
    func call(goal: String, steps: [RunStep]) async throws -> ModelResponse
}

public enum ModelResponse: Sendable {
    case toolRequest(ToolCall)
    case FinalAnswer(String)
}

public final class MockModelGateway: ModelGateway {
    public init() {}
    
    public func call(goal: String, steps: [RunStep]) async throws -> ModelResponse {
        let hasListedFiles = steps.contains {
            $0.type == .toolResult && $0.message.contains("list_files")
        }
            
            if !hasListedFiles {
                return .toolRequest(ToolCall(name: "list_files", arguments: ["path": "."])
            }
        }
}

public struct ToolCall: Sendable {
    public var name: String
    public var arguments: [String: String]
    
    public init(name: String, arguments: [String: String]) {
        self.name = name
        self.arguments = arguments
    }
}
