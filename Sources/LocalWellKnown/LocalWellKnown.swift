import ArgumentParser
import Foundation

enum LocalWellKnown {
    private static let decoder = JSONDecoder()

    static func run(
        strategy: AppIdStrategy,
        autoTrustSSH: Bool,
        port: UInt16,
        entitlementsFile: String?,
        exit: @escaping (Int32) -> Void
    ) async throws {
        let remoteHost = "localhost.run"
        let sshCommand = "ssh -R 80:localhost:\(port) \(remoteHost)"

        let source = Current.makeInterruptHandler {
            cleanUpSSH(command: sshCommand)
            exit(SIGINT)
        }

        source.resume()

        cleanUpSSH(command: sshCommand)

        var sshTrustCommand = "ssh-keygen -F \(remoteHost)"

        if autoTrustSSH {
            sshTrustCommand += " || ssh-keyscan \(remoteHost) >> ~/.ssh/known_hosts"
        }

        do {
            try Current.shell.run(sshTrustCommand)
        } catch LocalWellKnownError.shellFailure {
            throw LocalWellKnownError.sshKnownHostMissing(host: remoteHost)
        }

        var domain: URL?

        for try await data in Current.shell.runAsyncStream("\(sshCommand) -- --output json") {
            guard let response = try? decoder.decode(SSHResponse.self, from: data) else {
                continue
            }
            domain = response.address
            break
        }

        guard let domain else { throw ExitCode(1) }

        if let entitlementsFile {
            try ["applinks", "webcredentials", "appclips", "activitycontinuation"].enumerated().forEach { index, entitlement in
                let makeCommand: (String, String?) -> String = { command, type in
                    "/usr/libexec/PlistBuddy -c '\(command) :com.apple.developer.associated-domains:\(index) \(type.map { $0 + " " } ?? "")\(entitlement):\(domain)' \(entitlementsFile)"
                }
                let addCommand = makeCommand("add", "string")
                let setCommand = makeCommand("set", nil)
                try Current.shell.run("\(setCommand) || \(addCommand)")
            }
        } else {
            Current.print("Add \(domain) to your app's entitlements file.")
        }

        let json: String

        switch strategy {
        case let .manual(appIds):
            json = makeJson(appIds: appIds)
        case let .project(file, scheme):
            json = makeJson(appIds: try getXcodeAppIds(strategy: "project", file: file, scheme: scheme))
        case let .workspace(file, scheme):
            json = makeJson(appIds: try getXcodeAppIds(strategy: "workspace", file: file, scheme: scheme))
        case let .json(file):
            json = try Current.contentsOfFile(file)
        }

        try Current.server.run(port, domain.absoluteString, json)
    }

    private static func getXcodeAppIds(strategy: String, file: String, scheme: String) throws -> [String] {
        let data = try Current.shell.run("xcrun xcodebuild -quiet -showBuildSettings  -json -\(strategy) '\(file)' -scheme '\(scheme)' 2> /dev/null")
        let response = try decoder.decode(BuildSettingsResponse.self, from: data)
        guard let appId = response.appId else { throw ExitCode.failure }
        return [appId]
    }

    private static func makeJson(appIds: [String]) -> String {
        "{\"applinks\":{\"details\":[{\"appIds\":\(appIds)}]},\"webcredentials\":{\"apps\":\(appIds)},\"appclips\":{\"apps\":\(appIds)},\"activitycontinuation\":{\"apps\":\(appIds)}}"
    }

    private static func cleanUpSSH(command: String) {
        do {
            try Current.shell.run("ps -o pid -o command | grep -E '^\\s*\\d+ \(command)' | awk \"{print \\$1}\" | xargs kill")
        } catch {}
    }
}

extension LocalWellKnown {
    enum AppIdStrategy {
        case manual(appIds: [String])
        case project(file: String, scheme: String)
        case workspace(file: String, scheme: String)
        case json(file: String)
    }

    struct SSHResponse: Codable {
        let address: URL
    }

    struct BuildSettingsResponse {
        var appId: String? {
            actionSettings
                .first { $0.action == "build" }
                .map(\.buildSettings)
                .map { "\($0.teamId).\($0.bundleId)" }
        }

        let actionSettings: [ActionSettings]

        struct ActionSettings: Codable {
            let action: String
            let buildSettings: Settings

            struct Settings: Codable {
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

extension LocalWellKnown.BuildSettingsResponse: Codable {
    init(from decoder: Decoder) throws {
        self.actionSettings = try .init(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try actionSettings.encode(to: encoder)
    }
}
