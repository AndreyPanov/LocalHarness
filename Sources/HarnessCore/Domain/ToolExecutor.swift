final class ToolExecutor: Sendable {
    func execute(_ call: ToolCall) async -> ToolResult {
        switch call.name {
        case "list_files":
            return try listFiles(call)
        default:
            throw HarnessError.unknownTool(call.name)
        }
    }
    
    private func listFiles(_ call: ToolCall) throws -> ToolResult {
        let path = call.arguments["path"] ?? "."
        let url = URL(fileURLWithPath: path)
        
        let files = try FileManager.default.contentsOfDirectory(atPath: url.path)
        
        return ToolResult(toolName: "list_files", output: files.sorted().joined(separator: "\n"))
        
    }
}

