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
        let source = Current.makeInterruptHandler {
            Current.sshClient.cleanup(port)
            exit(SIGINT)
        }

        source.resume()

        Current.sshClient.cleanup(port)

        try Current.sshClient.addKnownHostIfNeeded()

        let domain = try await Current.sshClient.startRemoteTunnel(decoder, port).address.absoluteString

        if let entitlementsFile {
            try ["applinks", "webcredentials"].enumerated().forEach { index, entitlement in
                try Current.entitlementsClient.setOrAddEntitlementToFile(index, entitlement, domain, entitlementsFile)
            }
        } else {
            print("Add \(domain) to your app's entitlements file.", to: &Current.stdout)
        }

        let json: String

        switch strategy {
        case let .manual(appIds):
            json = makeJson(appIds: appIds)
        case let .project(file, scheme):
            json = makeJson(appIds: try Current.xcodeClient.getAppIds(decoder, "project", file, scheme))
        case let .workspace(file, scheme):
            json = makeJson(appIds: try Current.xcodeClient.getAppIds(decoder, "workspace", file, scheme))
        case let .json(file):
            json = try Current.contentsOfFile(file)
        }

        try Current.serverClient.run(port: port, remoteHost: domain, json: json)
    }

    private static func makeJson(appIds: [String]) -> String {
        "{\"applinks\":[\"details\":[{\"appIds\":\(appIds)}],\"webcredentials\":{\"apps\":\(appIds)}"
    }
}

extension LocalWellKnown {
    enum AppIdStrategy {
        case manual(appIds: [String])
        case project(file: String, scheme: String)
        case workspace(file: String, scheme: String)
        case json(file: String)
    }
}
