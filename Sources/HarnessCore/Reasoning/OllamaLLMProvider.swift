import Foundation

final class OllamaLLMProvider: LLMProvider {
    private let baseURL: URL
    
    init(baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.baseURL = baseURL
    }
    
    func complete(_ request: LLMRequest) async throws -> String {
        let url = baseURL.appendingPathComponent("/api/chat")
        let actionSchema: [String: Any] = [
            "oneOf": [
                    [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["request_tool"]
                            ],
                            "tool": [
                                "type": "string",
                                "enum": ["list_files", "read_file"]
                            ],
                            "arguments": [
                                "type": "object",
                                "additionalProperties": false,
                                "properties": [
                                    "path": [
                                        "type": "string",
                                        "minLength": 1
                                    ]
                                ],
                                "required": ["path"]
                            ],
                            "finalAnswer": [
                                "type": "null"
                            ]
                        ],
                        "required": [
                            "action",
                            "tool",
                            "arguments",
                            "finalAnswer"
                        ]
                    ],
                    [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["finish"]
                            ],
                            "tool": [
                                "type": "null"
                            ],
                            "arguments": [
                                "type": "object",
                                "additionalProperties": false,
                                "maxProperties": 0
                            ],
                            "finalAnswer": [
                                "type": "string",
                                "minLength": 1
                            ]
                        ],
                        "required": [
                            "action",
                            "tool",
                            "arguments",
                            "finalAnswer"
                        ]
                    ]
                ]
           ]
        let body: [String: Any] = [
              "model": request.model,
              "messages": [
                  [
                      "role": "system",
                      "content": request.systemPrompt
                  ],
                  [
                      "role": "user",
                      "content": request.userPrompt
                  ]
              ],
              "stream": false,
              "format": actionSchema,
              "options": [
                  "temperature": 0
              ]
          ]
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw HarnessError.llmRequestFailed
        }
        
        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return decoded.message.content
    }
}

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let format: String
}

private struct OllamaMessage: Codable {
    let role: String
    let content: String
}

private struct OllamaChatResponse: Decodable {
    let message: OllamaMessage
}
