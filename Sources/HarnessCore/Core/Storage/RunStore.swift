protocol RunStore: Sendable {
    func save(_ run: Run) throws
    func load(id: String) throws -> Run
}
