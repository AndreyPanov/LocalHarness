import ArgumentParser

@available(macOS 10.15, *)
@main
struct HarnessCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "harness",
        abstract: "Local Harness CLI",
        subcommands: [ RunCommand.self ]
    )
}
