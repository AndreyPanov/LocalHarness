import Foundation

final class MockAgentReasoner: AgentReasoner {

    func nextAction(for run: Run) async throws -> AgentAction {
        let hasListedFiles = run.steps.contains {
            $0.type == .toolResult && $0.toolName == "list_files"
        }
        let hasReadPackageFile = run.steps.contains {
            $0.type == .toolResult && $0.toolName == "read_file"
        }
        if !hasListedFiles {
            return .requestTool(
                ToolCall(name: "list_files", arguments: ["path": "."]))
        }
        if !hasReadPackageFile {
            return .requestTool(ToolCall(name: "read_file", arguments: ["path": "Package.swift"]))
        }
        return .finish("I inspected the project structure, read Package.swift and saved the run trace.")
    }
}
