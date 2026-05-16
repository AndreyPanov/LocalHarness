// The Swift Programming Language
// https://docs.swift.org/swift-book

@main
struct LocalHarness {
    static func main() {
        let harness = Harness()
        let run = try await harness.run(goal: goal)
        print(run.finalAnswer ?? "No final answer")
    }
}
