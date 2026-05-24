struct ToolCall: Sendable {
    let name: String
    let arguments: [String: String]
    
    public init(name: String, arguments: [String: String]) {
        print("[Trace] ToolCall.init(name: \(name), arguments: \(arguments))")
        self.name = name
        self.arguments = arguments
    }
}
