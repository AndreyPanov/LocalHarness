import ArgumentParser
import HarnessCore

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a harness task."
    )

    @Argument(help: "The goal for this harness run.")
    var goal: String

    func run() async throws {
        print("[Trace] RunCommand.run(goal: \(goal))")
        let harness = Harness()
        let run = try await harness.run(goal: goal)
        print("Run completed: \(run.id)")
        print("Status: \(run.status.rawValue)")
        print("")
        if let finalAnswer = run.finalAnswer {
            print(finalAnswer)
        } else {
            print("No final answer.")
        }
        print("")
        print("Trace saved in: runs/\(run.id).json")
    }
}
