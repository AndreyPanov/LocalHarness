final class MockAgentReasoner: AgentReasoner {
    func nextAction(for run: Run) async throws -> AgentAction {
        let hasListedFiles = run.steps.contains {
            $.type == .toolResult && $.message.contains("listed_files")
        }
        if !hasListedFiles {
            return .requestTool(
                ToolCall(name: "list_files", arguments: ["path": "."])
            )
        }
        return .finish("I inspected the project structure and saved the run trace.")
    }
}
