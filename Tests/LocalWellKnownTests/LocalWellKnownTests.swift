import XCTest
@testable import LocalWellKnown

final class LocalWellKnownTests: XCTestCase {
    private let jsonEncoder = JSONEncoder()

    private var commands: [String] = []
    private var file: String?
    private var json: String?
    private var output: [String] = []
    private var port: UInt16?
    private var tunnelHost: String?

    override func setUp() async throws {
        commands = []
        file = nil
        json = nil
        port = nil
        output = []
        tunnelHost = nil

        Current.shell._run = { [unowned self] command in
            self.commands.append(command)
            return .init()
        }
        Current.shell.runAsyncStream = { [unowned self] command in
            self.commands.append(command)
            return .init {
                try self.jsonEncoder.encode(LocalWellKnown.SSHResponse(address: URL(string: "com.blah")!))
            }
        }
        Current.server.run = { [unowned self] port, tunnelHost, json in
            self.port = port
            self.tunnelHost = tunnelHost
            self.json = json
        }
        Current.print = { [unowned self] in
            self.output.append($0)
        }
        Current.contentsOfFile = { [unowned self] file in
            self.file = file
            return "{\"iamjson\":34}"
        }
    }

    func testManualStrategy() async throws {
        try await LocalWellKnown.run(
            strategy: .manual(appIds: ["com.1234"]),
            port: 8765,
            entitlementsFile: nil
        ) { _ in }

        XCTAssertEqual(
            commands,
            [
                "ps -o pid -o command | grep -E \'^\\s*\\d+ ssh -R 80:localhost:8765 localhost.run\' | awk \"{print \\$1}\" | xargs kill",
                "ssh-keygen -F localhost.run || ssh-keyscan -H localhost.run >> ~/.ssh/known_hosts",
                "ssh -R 80:localhost:8765 localhost.run -- --output json",
            ]
        )
        XCTAssertEqual(output, ["Add com.blah to your app\'s entitlements file."])
        XCTAssertEqual(port, 8765)
        XCTAssertEqual(tunnelHost, "com.blah")
        XCTAssertEqual(json, "{\"applinks\":[\"details\":[{\"appIds\":[\"com.1234\"]}],\"webcredentials\":{\"apps\":[\"com.1234\"]}")
    }

    func testProjectFileStrategy() async throws {
        Current.shell._run = { [unowned self] command in
            self.commands.append(command)
            return command.starts(with: "xcrun xcodebuild") ?
                try self.jsonEncoder.encode(LocalWellKnown.BuildSettingsResponse.init(actionSettings: [.init(action: "build", buildSettings: .init(teamId: "team123", bundleId: "com.bundle.example"))])) :
                .init()
        }

        try await LocalWellKnown.run(
            strategy: .project(file: "hello.xcodeproj", scheme: "ImAScheme"),
            port: 8765,
            entitlementsFile: "ImAScheme/ImAScheme.entitlements"
        ) { _ in }

        XCTAssertEqual(
            commands,
            [
                "ps -o pid -o command | grep -E \'^\\s*\\d+ ssh -R 80:localhost:8765 localhost.run\' | awk \"{print \\$1}\" | xargs kill",
                "ssh-keygen -F localhost.run || ssh-keyscan -H localhost.run >> ~/.ssh/known_hosts",
                "ssh -R 80:localhost:8765 localhost.run -- --output json",
                "/usr/libexec/PlistBuddy -c \'set :com.apple.developer.associated-domains:0 applinks:com.blah\' ImAScheme/ImAScheme.entitlements || /usr/libexec/PlistBuddy -c \'add :com.apple.developer.associated-domains:0 string applinks:com.blah\' ImAScheme/ImAScheme.entitlements",
                "/usr/libexec/PlistBuddy -c \'set :com.apple.developer.associated-domains:1 webcredentials:com.blah\' ImAScheme/ImAScheme.entitlements || /usr/libexec/PlistBuddy -c \'add :com.apple.developer.associated-domains:1 string webcredentials:com.blah\' ImAScheme/ImAScheme.entitlements",
                "xcrun xcodebuild -quiet -showBuildSettings  -json -project \'hello.xcodeproj\' -scheme \'ImAScheme\' 2> /dev/null",
            ]
        )
        XCTAssertEqual(output, [])
        XCTAssertEqual(port, 8765)
        XCTAssertEqual(tunnelHost, "com.blah")
        XCTAssertEqual(json, "{\"applinks\":[\"details\":[{\"appIds\":[\"team123.com.bundle.example\"]}],\"webcredentials\":{\"apps\":[\"team123.com.bundle.example\"]}")
    }


    func testWorkspaceFileStrategy() async throws {
        Current.shell._run = { [unowned self] command in
            self.commands.append(command)
            return command.starts(with: "xcrun xcodebuild") ?
                try self.jsonEncoder.encode(LocalWellKnown.BuildSettingsResponse.init(actionSettings: [.init(action: "build", buildSettings: .init(teamId: "team123", bundleId: "com.bundle.example"))])) :
                .init()
        }

        try await LocalWellKnown.run(
            strategy: .workspace(file: "hello.xcworkspace", scheme: "ImAScheme"),
            port: 8765,
            entitlementsFile: "ImAScheme/ImAScheme.entitlements"
        ) { _ in }

        XCTAssertEqual(
            commands,
            [
                "ps -o pid -o command | grep -E \'^\\s*\\d+ ssh -R 80:localhost:8765 localhost.run\' | awk \"{print \\$1}\" | xargs kill",
                "ssh-keygen -F localhost.run || ssh-keyscan -H localhost.run >> ~/.ssh/known_hosts",
                "ssh -R 80:localhost:8765 localhost.run -- --output json",
                "/usr/libexec/PlistBuddy -c \'set :com.apple.developer.associated-domains:0 applinks:com.blah\' ImAScheme/ImAScheme.entitlements || /usr/libexec/PlistBuddy -c \'add :com.apple.developer.associated-domains:0 string applinks:com.blah\' ImAScheme/ImAScheme.entitlements",
                "/usr/libexec/PlistBuddy -c \'set :com.apple.developer.associated-domains:1 webcredentials:com.blah\' ImAScheme/ImAScheme.entitlements || /usr/libexec/PlistBuddy -c \'add :com.apple.developer.associated-domains:1 string webcredentials:com.blah\' ImAScheme/ImAScheme.entitlements",
                "xcrun xcodebuild -quiet -showBuildSettings  -json -workspace \'hello.xcworkspace\' -scheme \'ImAScheme\' 2> /dev/null",
            ]
        )
        XCTAssertEqual(output, [])
        XCTAssertEqual(port, 8765)
        XCTAssertEqual(tunnelHost, "com.blah")
        XCTAssertEqual(json, "{\"applinks\":[\"details\":[{\"appIds\":[\"team123.com.bundle.example\"]}],\"webcredentials\":{\"apps\":[\"team123.com.bundle.example\"]}")
    }

    func testJsonFileStrategy() async throws {
        try await LocalWellKnown.run(
            strategy: .json(file: "example.json"),
            port: 123,
            entitlementsFile: nil
        ) { _ in }

        XCTAssertEqual(
            commands,
            [
                "ps -o pid -o command | grep -E \'^\\s*\\d+ ssh -R 80:localhost:123 localhost.run\' | awk \"{print \\$1}\" | xargs kill",
                "ssh-keygen -F localhost.run || ssh-keyscan -H localhost.run >> ~/.ssh/known_hosts",
                "ssh -R 80:localhost:123 localhost.run -- --output json",
            ]
        )
        XCTAssertEqual(output, ["Add com.blah to your app\'s entitlements file."])
        XCTAssertEqual(port, 123)
        XCTAssertEqual(tunnelHost, "com.blah")
        XCTAssertEqual(json, "{\"iamjson\":34}")
        XCTAssertEqual(file, "example.json")
    }
}
