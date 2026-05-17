struct ToolResult: Codable, Sendable {
    let toolName: String
    let output: String
    
    init(toolName: String, output: String) {
        print("[Trace] ToolResult.init(toolName: \(toolName), output: \(output))")
        self.toolName = toolName
        self.output = output
    }
}
