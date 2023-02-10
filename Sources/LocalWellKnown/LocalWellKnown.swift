import ArgumentParser
import Foundation

enum LocalWellKnown {
    private static let decoder = JSONDecoder()

    static func run(
        strategy: AppIdStrategy,
        port: UInt16,
        entitlementsFile: String?,
        exit: @escaping (Int32) -> Void
    ) async throws {
        let remoteHost = "localhost.run"
        let sshCommand = "ssh -R 80:localhost:\(port) \(remoteHost)"

        let source = handleInterrupt {
            cleanUpSSH(command: sshCommand)
            exit(SIGINT)
        }

        source.resume()

        cleanUpSSH(command: sshCommand)

        try await Shell.runAsync("ssh-keygen -F \(remoteHost) || ssh-keyscan -H \(remoteHost) >> ~/.ssh/known_hosts")

        var domain: URL?

        for try await data in Shell.runAsyncStream("\(sshCommand) -- --output json") {
            guard let response = try? decoder.decode(SSHResponse.self, from: data) else {
                continue
            }
            domain = response.address
            break
        }

        guard let domain else { throw ExitCode(1) }

        if let entitlementsFile {
            try await ["applinks", "webcredentials"].enumerated().forEach { index, entitlement in
                let makeCommand: (String, String?) -> String = { command, type in
                    "/usr/libexec/PlistBuddy -c '\(command) :com.apple.developer.associated-domains:\(index) \(type.map { $0 + " " } ?? "")\(entitlement):\(domain)' \(entitlementsFile)"
                }
                let addCommand = makeCommand("add", "string")
                let setCommand = makeCommand("set", nil)
                try await Shell.runAsync("\(addCommand) || \(setCommand)")
            }
        } else {
            print("Add \(domain) to your app's entitlements file.")
        }

        let appIds: [String]

        switch strategy {
        case let .manual(ids):
            appIds = ids
        case let .project(file, scheme):
            appIds = try getXcodeAppIds(strategy: "project", file: file, scheme: scheme)
        case let .workspace(file, scheme):
            appIds = try getXcodeAppIds(strategy: "workspace", file: file, scheme: scheme)
        }

        let server = Server(port: port, appIds: appIds)
        try server.run()
    }

    private static func getXcodeAppIds(strategy: String, file: String, scheme: String) throws -> [String] {
        let data = try Shell.run("xcrun xcodebuild -quiet -showBuildSettings  -json -\(strategy) '\(file)' -scheme '\(scheme)' 2> /dev/null")
        let response = try decoder.decode(BuildSettingsResponse.self, from: data)
        guard let appId = response.appId else { throw ExitCode(1) }
        return [appId]
    }

    private static func cleanUpSSH(command: String) {
        _ = try? Shell.run("ps -o pid -o command | grep -E '^\\s*\\d+ \(command)' | awk \"{print \\$1}\" | xargs kill")
    }

    private static func handleInterrupt(handler: @escaping () -> Void) -> DispatchSourceSignal {
        signal(SIGINT, SIG_IGN)

        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler(handler: handler)

        return source
    }
}

extension LocalWellKnown {
    enum AppIdStrategy {
        case manual(appIds: [String])
        case project(file: String, scheme: String)
        case workspace(file: String, scheme: String)
    }
}

private extension LocalWellKnown {
    struct SSHResponse: Decodable {
        let address: URL
    }

    struct BuildSettingsResponse: Decodable {
        var appId: String? {
            actionSettings
                .first { $0.action == "build" }
                .map(\.buildSettings)
                .map { "\($0.teamId).\($0.bundleId)" }
        }

        private let actionSettings: [ActionSettings]

        init(from decoder: Decoder) throws {
            self.actionSettings = try .init(from: decoder)
        }

        struct ActionSettings: Decodable {
            let action: String
            let buildSettings: Settings

            struct Settings: Decodable {
                private enum CodingKeys: String, CodingKey {
                    case teamId = "DEVELOPMENT_TEAM"
                    case bundleId = "PRODUCT_BUNDLE_IDENTIFIER"
                }

                let teamId: String
                let bundleId: String
            }
        }
    }
}
