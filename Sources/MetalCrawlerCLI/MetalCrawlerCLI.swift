import ArgumentParser

@available(macOS 10.15, *)
@main
struct MetalCrawlerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "metal-crawler",
        abstract: "Monthly Metal Crawler CLI",
        subcommands: [CrawlMetalCommand.self]
    )
}
