import ArgumentParser

struct ScoutMetalCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scout-metal",
        abstract: "Build a monthly metal release report."
    )

    @Option(help: "Month to scout, formatted as YYYY-MM.")
    var month: String

    func run() async throws {
        throw ValidationError("scout-metal is not implemented yet.")
    }
}
