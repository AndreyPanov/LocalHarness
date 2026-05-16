enum HarnessError: Error, Sendable {
    case maxIterationsExceeded(Int)
    case unknownTool(String)
    case missingToolArgument(toolName: String, argumentName: String)
}
