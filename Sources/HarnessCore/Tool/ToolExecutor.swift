import Foundation

final class ToolExecutor: Sendable {
    func execute(_ call: ToolCall) async throws -> ToolResult {
        switch call.name {
        case "list_files":
            return try listFiles(call)
        case "read_file":
            return try readFile(call)
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
    
    private func readFile(_ call: ToolCall) throws -> ToolResult {
        guard let path = call.arguments["path"] else {
            throw HarnessError.missingToolArgument(toolName: "read_file", argumentName: "path")
        }
        let url = URL(fileURLWithPath: path)
        let contents = try String(contentsOf: url, encoding: .utf8)
        return ToolResult(toolName: "read_file", output: contents)
    }
}

