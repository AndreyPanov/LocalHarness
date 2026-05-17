import Foundation

final class JsonRunStore: RunStore {
    private let runDirectory: URL
    
    init(runDirectory: URL = URL(fileURLWithPath: "runs")) {
        print("[Trace] JsonRunStore.init(runDirectory: \(runDirectory))")
        self.runDirectory = runDirectory
    }
    
    func save(_ run: Run) throws {
        print("[Trace] JsonRunStore.save(run: \(run))")
        try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        let url = runDirectory.appendingPathComponent("\(run.id).json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(run)
        try data.write(to: url, options: .atomic)
    }
    
    func load(id: String) throws -> Run {
        print("[Trace] JsonRunStore.load(id: \(id))")
        let url = runDirectory.appendingPathComponent("\(id).json")
        let data = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(Run.self, from: data)
    }
}
