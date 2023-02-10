import ArgumentParser

struct Project: AsyncParsableCommand {
    @OptionGroup var globals: GlobalOptions

    @OptionGroup var strategyOptions: FileStrategyOptions

    func run() async throws {
        try await LocalWellKnown.run(
            strategy: .project(file: strategyOptions.file, scheme: strategyOptions.scheme),
            port: globals.port,
            entitlementsFile: globals.entitlementsFile
        ) { exitCode in
            Self.exit(withError: ExitCode(exitCode))
        }
    }
}
