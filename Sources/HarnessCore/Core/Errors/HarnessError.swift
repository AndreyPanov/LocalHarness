enum HarnessError: Error, Sendable {
    case unknownTool(String)
    case missingToolArgument(toolName: String, argumentName: String)
    case maxIterationsExceeded(Int)
    case llmRequestFailed
    case invalidAgentAction(String)
    case invalidMonth(String)
    case crawlClientNotImplemented(String)
}
