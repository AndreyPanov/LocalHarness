import ArgumentParser

@available(macOS 10.15, *)
@main
struct MetalMonthlyCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "harness",
        abstract: "Monthly Metal Scout CLI",
        subcommands: [ScoutMetalCommand.self]
    )
}
