import ArgumentParser

struct JSONFile: AsyncParsableCommand {
    @OptionGroup var globals: GlobalOptions

    @Argument var file: String

    func run() async throws {
        try await LocalWellKnown.run(
            strategy: .json(file: file),
            port: globals.port,
            entitlementsFile: globals.entitlementsFile
        ) { exitCode in
            Self.exit(withError: ExitCode(exitCode))
        }
    }
}
