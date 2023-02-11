import ArgumentParser
import Foundation

@main
struct Runner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "local-well-known")

    @Option(name: .shortAndLong) var projectFile: String?
    @Option(name: .shortAndLong) var workspaceFile: String?
    @Option(name: .shortAndLong) var scheme: String?
    @Option(name: .shortAndLong) var jsonFile: String?
    @Option(name: .shortAndLong, parsing: .upToNextOption) var appIds: [String] = []

    @Option(name: .shortAndLong) var entitlementsFile: String?

    @Option var port: UInt16 = 8080

    func run() async throws {
        try await LocalWellKnown.run(
            strategy: appIdStrategy,
            port: port,
            entitlementsFile: entitlementsFile
        ) { exitCode in
            Self.exit(withError: ExitCode(exitCode))
        }
    }

    private var appIdStrategy: LocalWellKnown.AppIdStrategy {
        get throws {
            if let jsonFile {
                return .json(file: jsonFile)
            } else if let projectFile {
                return .project(file: projectFile, scheme: try scheme.expected(optionName: "scheme"))
            } else if let workspaceFile {
                return .workspace(file: workspaceFile, scheme: try scheme.expected(optionName: "scheme"))
            } else if !appIds.isEmpty {
                return .manual(appIds: appIds)
            } else {
                throw ParserError.missingAppIdRetrievalOptions
            }
        }
    }
}

private extension Swift.Optional {
    func expected(optionName: String) throws -> Wrapped {
        guard case let .some(wrapped) = self else {
            throw ParserError.missingRequiredOption(option: optionName)
        }
        return wrapped
    }
}
