import Foundation

final class LLMAgentReasoner: AgentReasoner {
    private let provider: any LLMProvider
    private let model: String
    
    init(provider: any LLMProvider, model: String = "qwen2.5-coder:7b") {
        self.provider = provider
        self.model = model
    }
    
    func nextAction(for run: Run) async throws -> AgentAction {
        let response = try await provider.complete(LLMRequest(model: model, systemPrompt: systemPrompt, userPrompt: userPrompt(for: run)))
        let data = Data(response.utf8)
        let decoded = try JSONDecoder().decode(DecodedAgentAction.self, from: data)
        switch decoded.action {
        case "request_tool":
            guard let tool = decoded.tool else {
                throw HarnessError.invalidAgentAction(response)
            }
            guard let path = decoded.arguments["path"], !path.isEmpty else {
                throw HarnessError.missingToolArgument(toolName: tool, argumentName: "path")
            }
            return .requestTool(ToolCall(name: tool, arguments: decoded.arguments))
        case "finish":
            guard let finalAnswer = decoded.finalAnswer else {
                throw HarnessError.invalidAgentAction(response)
            }
            return .finish(finalAnswer)
        default:
            throw HarnessError.invalidAgentAction(response)
        }
    }
    
    private var systemPrompt: String {
        """
            You are an agent reasoner inside a local Swift harness.
            You must choose exactly one next action.
            Allowed actions:
            1. request_tool
            2. finish
            Available tools:
            Tool: list_files
            Required arguments:
            {
              "path": "."
            }
            Tool: read_file
            Required arguments:
            {
              "path": "Package.swift"
            }
            Rules:
            - Return ONLY valid JSON.
            - Never invent new action names.
            - Never use empty arguments for request_tool.
            - If you request list_files, arguments.path is required.
            - If you request read_file, arguments.path is required.
            - If the goal asks to inspect this Swift package, first use list_files with path ".", then read_file with path "Package.swift", then finish.
            - Do not add markdown.
            - Do not explain outside JSON.
            Example request_tool:
            {
              "action": "request_tool",
              "tool": "read_file",
              "arguments": {
                "path": "Package.swift"
              },
              "finalAnswer": null
            }
            Example finish:
            {
              "action": "finish",
              "tool": null,
              "arguments": {},
              "finalAnswer": "I inspected the Swift package."
            }
            """
    }

    private func userPrompt(for run: Run) -> String {
        let steps = run.steps.map { step in
            """
            - type: \(step.type.rawValue)
              toolName: \(step.toolName ?? "none")
              message: \(step.message)
            """
        }
        .joined(separator: "\n")
        return """
        Goal:
        \(run.goal)
        Current run status:
        \(run.status.rawValue)
        Steps so far:
        \(steps.isEmpty ? "No steps yet." : steps)
        Choose the next action.
        """
    }
}

private struct DecodedAgentAction: Decodable {
    let action: String
    let tool: String?
    let arguments: [String: String]
    let finalAnswer: String?
}
