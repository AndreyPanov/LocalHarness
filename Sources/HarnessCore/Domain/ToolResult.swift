struct ToolResult: Codable, Sendable {
    let toolName: String
    let output: String
    
    init(toolName: String, output: String) {
        self.toolName = toolName
        self.output = output
    }
}
