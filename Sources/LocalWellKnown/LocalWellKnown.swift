import ArgumentParser
import Foundation

enum LocalWellKnown {
    private static let snakeCaseDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let decoder = JSONDecoder()

    static func run(
        strategy: AppIdStrategy,
        port: UInt16,
        entitlementsFile: String?,
        exit: @escaping (Int32) -> Void
    ) async throws {
        let source = Current.makeInterruptHandler {
            cleanUpNgrok()
            exit(SIGINT)
        }

        source.resume()

        cleanUpNgrok()

        do {
            try Current.shell.run("which ngrok")
        } catch LocalWellKnownError.shellFailure {
            do {
                try Current.shell.run("brew install --cask ngrok")
            } catch {
                throw LocalWellKnownError.ngrokInstallationFailed
            }
        }

        _ = Current.shell.runAsyncStream("ngrok http \(port)")

        var tunnelUrl: URL?

        while tunnelUrl == nil {
            for try await data in Current.shell.runAsyncStream("curl http://127.0.0.1:4040/api/tunnels --silent --max-time 0.1") {
                guard
                    let response = try? snakeCaseDecoder.decode(NgrokResponse.self, from: data),
                    let url = response.tunnels.first?.publicUrl
                else {
                    continue
                }
                tunnelUrl = url
                break
            }
        }

        guard
            let tunnelUrl,
            let components = URLComponents(url: tunnelUrl, resolvingAgainstBaseURL: false),
            let domain = components.host
        else { throw ExitCode.failure }

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

        try Current.server.run(port, domain, json)
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

    private static func cleanUpNgrok() {
        do {
            try Current.shell.run("pkill ngrok")
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

    struct NgrokResponse: Codable {
        let tunnels: [Tunnel]

        struct Tunnel: Codable {
            let publicUrl: URL
        }
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
