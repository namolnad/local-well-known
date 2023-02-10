import ArgumentParser

struct Manual: AsyncParsableCommand {
    @OptionGroup var globals: GlobalOptions

    @Option var appIds: [String]

    func run() async throws {
        try await LocalWellKnown.run(
            strategy: .manual(appIds: appIds),
            port: globals.port,
            entitlementsFile: globals.entitlementsFile
        ) { exitCode in
            Self.exit(withError: ExitCode(exitCode))
        }
    }
}
