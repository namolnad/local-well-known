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

    @Flag(inversion: .prefixedNo) var autoTrustSSH: Bool = true

    @Option var port: UInt16 = 8080

    func run() async throws {
        try await LocalWellKnown.run(
            strategy: appIdStrategy,
            autoTrustSSH: autoTrustSSH,
            port: port,
            entitlementsFile: entitlementsFile
        ) { exitCode in
            Self.exit(withError: ExitCode(exitCode))
        }
    }

    func validate() throws {
        _ = try appIdStrategy
    }

    private var appIdStrategy: LocalWellKnown.AppIdStrategy {
        get throws {
            if let jsonFile {
                return .json(file: jsonFile)
            } else if let projectFile {
                return .project(file: projectFile, scheme: try scheme.required(option: "scheme"))
            } else if let workspaceFile {
                return .workspace(file: workspaceFile, scheme: try scheme.required(option: "scheme"))
            } else if !appIds.isEmpty {
                return .manual(appIds: appIds)
            } else {
                throw LocalWellKnownError.parsingMissingAppIdRetrievalOptions
            }
        }
    }
}

private extension Swift.Optional {
    func required(option: String) throws -> Wrapped {
        guard case let .some(wrapped) = self else {
            throw LocalWellKnownError.parsingMissingRequiredOption(option: option)
        }
        return wrapped
    }
}
