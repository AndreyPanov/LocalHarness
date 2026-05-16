struct ToolCall: Sendable {
    let name: String
    let arguments: [String: String]
    
    public init(name: String, arguments: [String: String]) {
        self.name = name
        self.arguments = arguments
    }
}
