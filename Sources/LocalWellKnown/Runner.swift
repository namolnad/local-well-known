import ArgumentParser
import Foundation

// Set up remotetunnel
//  Option 1. check for (or install) and start ngrok, poll 127.0.0.1:4040/api/tunnels for publicUrl
//  Option 2. use ssh -R and localhost.run
//   2a. Use system command
//   2b. use swift-nio-ssh
// print url or update entitlements file
// update entitlements file if desired
// start server and pass in appIds
//   can take in project file and scheme to get app id instead of taking in appIds
//     xcrun xcodebuild -quiet -showBuildSettings -project '\(projectFile)' -json -scheme '\(scheme)' | jq -r '.[0].buildSettings | "\\(.DEVELOPMENT_TEAM).\\(.PRODUCT_BUNDLE_IDENTIFIER)"'

@main
struct Runner: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "lwk")

    @Argument
    var appIds: [String]

    @Option
    var port: UInt16 = 8080

    @Option
    var entitlementsFile: String?

    func run() async throws {
        await cleanUp()

        let remoteHost = "localhost.run"
        try await Shell.runAsync("ssh-keygen -F \(remoteHost) || ssh-keyscan -H \(remoteHost) >> ~/.ssh/known_hosts")

        let decoder = JSONDecoder()
        var domain: URL?

        for try await data in Shell.runAsyncStream("ssh -R 80:localhost:\(port) \(remoteHost) -- --output json") {
            struct Response: Decodable { let address: URL }
            guard let response = try? decoder.decode(Response.self, from: data) else {
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

        let server = Server(port: port, appIds: appIds)
        try server.run()
    }

    func cleanUp() async {
        // TODO: cleanup on sigint
        do {
            try await Shell.runAsync("pkill ssh")
        } catch {}
    }
}
