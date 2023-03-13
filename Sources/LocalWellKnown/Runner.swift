import ArgumentParser
import Foundation

@main
struct Runner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "local-well-known")

    @Option(name: .shortAndLong, help: "When using this option in conjunction with `--scheme`, your app's id will be automatically determined.")
    var projectFile: String?
    @Option(name: .shortAndLong, help: "When using this option in conjunction with `--scheme`, your app's id will be automatically determined.")
    var workspaceFile: String?
    @Option(name: .shortAndLong, help: "When using this option in conjunction with `--project-file` or `--workspace-file`, your app's id will be automatically determined.")
    var scheme: String?
    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "If you prefer, you can manually set the app-ids to be hosted.")
    var appIds: [String] = []
    @Option(name: .shortAndLong, help: "For complex apple-app-site-association files, use this option to host your custom file accordingly.")
    var jsonFile: String?

    @Option(name: .shortAndLong, help: "By setting this option, your entitlements file will be automatically updated to include the tunnel url for applinks and webcredentials.")
    var entitlementsFile: String?

    @Option(help: "By default the local server will be hosted on port 8080. If this port is already in use, you can select a different port by setting this option.")
    var port: UInt16 = 8080

    func run() async throws {
        try await LocalWellKnown.run(
            strategy: appIdStrategy,
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
