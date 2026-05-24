enum AgentAction: Sendable {
    case requestTool(ToolCall)
    case finish(String)
}
