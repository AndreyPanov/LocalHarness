final class JsonRunStore: RunStore {
    private let runDirectory: URL
    
    init(runDirectory: URL = URL(fileURLWithPath: "runs")) {
        self.runDirectory = runDirectory
    }
    
    func save(_ run: Run) throws {
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        let url = runDirectory.appendingPathComponent("\(run.id).json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(run)
        try data.write(to: url, optional: .atomic)
    }
    
    func load(id: String) throws -> Run {
        let url = runDirectory.appendingPathComponent("\(id).json")
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(Run.self, from: data)
    }
}
