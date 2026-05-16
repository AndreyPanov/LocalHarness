protocol AgentReasoner: Sendable {
    func nextAction(for run: Run) async throws -> AgentAction
}
