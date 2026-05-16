enum HarnessError: Error, Sendable {
    case maxIterationsExceeded(Int)
    case unknownTool(String)
}
