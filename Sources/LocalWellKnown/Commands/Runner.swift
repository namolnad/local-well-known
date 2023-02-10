import ArgumentParser
import Foundation

@main
struct Runner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "local-well-known",
        subcommands: [
            Manual.self,
            Project.self,
            Workspace.self,
            JSONFile.self
        ],
        defaultSubcommand: Manual.self
    )

    // Not used, exists to provide usage hints re: default command for top level --help
    @OptionGroup var globals: GlobalOptions
}

struct GlobalOptions: ParsableArguments {
    @Option(name: .shortAndLong) var port: UInt16 = 8080
    @Option(name: .shortAndLong) var entitlementsFile: String?
}

struct FileStrategyOptions: ParsableArguments {
    @Argument var file: String
    @Option(name: .shortAndLong) var scheme: String
}
