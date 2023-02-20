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
                try self.jsonEncoder.encode(
                    LocalWellKnown.NgrokResponse(
                        tunnels: [.init(publicUrl: XCTUnwrap(URL(string: "https://e315-47-208-216-108.ngrok.io")))]
                    )
                )
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
                "pkill ngrok",
                "which ngrok",
                "ngrok http 8765",
                "curl http://127.0.0.1:4040/api/tunnels --silent --max-time 0.1",
            ]
        )
        XCTAssertEqual(output, ["Add e315-47-208-216-108.ngrok.io to your app\'s entitlements file."])
        XCTAssertEqual(port, 8765)
        XCTAssertEqual(tunnelHost, "e315-47-208-216-108.ngrok.io")
        XCTAssertEqual(json, "{\"applinks\":{\"details\":[{\"appIds\":[\"com.1234\"]}],\"webcredentials\":{\"apps\":[\"com.1234\"]}}}")
    }

    func testProjectFileStrategy() async throws {
        Current.shell._run = { [unowned self] command in
            self.commands.append(command)
            return command.starts(with: "xcrun xcodebuild") ?
                try self.jsonEncoder.encode(LocalWellKnown.BuildSettingsResponse.init(actionSettings: [.init(action: "build", buildSettings: .init(teamId: "team123", bundleId: "com.bundle.example"))])) :
                .init()
        }

        try! await LocalWellKnown.run(
            strategy: .project(file: "hello.xcodeproj", scheme: "ImAScheme"),
            port: 8765,
            entitlementsFile: "ImAScheme/ImAScheme.entitlements"
        ) { _ in }

        XCTAssertEqual(
            commands,
            [
                "pkill ngrok",
                "which ngrok",
                "ngrok http 8765",
                "curl http://127.0.0.1:4040/api/tunnels --silent --max-time 0.1",
                "/usr/libexec/PlistBuddy -c \'set :com.apple.developer.associated-domains:0 applinks:e315-47-208-216-108.ngrok.io\' ImAScheme/ImAScheme.entitlements || /usr/libexec/PlistBuddy -c \'add :com.apple.developer.associated-domains:0 string applinks:e315-47-208-216-108.ngrok.io\' ImAScheme/ImAScheme.entitlements",
                "/usr/libexec/PlistBuddy -c \'set :com.apple.developer.associated-domains:1 webcredentials:e315-47-208-216-108.ngrok.io\' ImAScheme/ImAScheme.entitlements || /usr/libexec/PlistBuddy -c \'add :com.apple.developer.associated-domains:1 string webcredentials:e315-47-208-216-108.ngrok.io\' ImAScheme/ImAScheme.entitlements",
                "xcrun xcodebuild -quiet -showBuildSettings  -json -project \'hello.xcodeproj\' -scheme \'ImAScheme\' 2> /dev/null",
            ]
        )
        XCTAssertEqual(output, [])
        XCTAssertEqual(port, 8765)
        XCTAssertEqual(tunnelHost, "e315-47-208-216-108.ngrok.io")
        XCTAssertEqual(json, "{\"applinks\":{\"details\":[{\"appIds\":[\"team123.com.bundle.example\"]}],\"webcredentials\":{\"apps\":[\"team123.com.bundle.example\"]}}}")
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
                "pkill ngrok",
                "which ngrok",
                "ngrok http 8765",
                "curl http://127.0.0.1:4040/api/tunnels --silent --max-time 0.1",
                "/usr/libexec/PlistBuddy -c \'set :com.apple.developer.associated-domains:0 applinks:e315-47-208-216-108.ngrok.io\' ImAScheme/ImAScheme.entitlements || /usr/libexec/PlistBuddy -c \'add :com.apple.developer.associated-domains:0 string applinks:e315-47-208-216-108.ngrok.io\' ImAScheme/ImAScheme.entitlements",
                "/usr/libexec/PlistBuddy -c \'set :com.apple.developer.associated-domains:1 webcredentials:e315-47-208-216-108.ngrok.io\' ImAScheme/ImAScheme.entitlements || /usr/libexec/PlistBuddy -c \'add :com.apple.developer.associated-domains:1 string webcredentials:e315-47-208-216-108.ngrok.io\' ImAScheme/ImAScheme.entitlements",
                "xcrun xcodebuild -quiet -showBuildSettings  -json -workspace \'hello.xcworkspace\' -scheme \'ImAScheme\' 2> /dev/null",
            ]
        )
        XCTAssertEqual(output, [])
        XCTAssertEqual(port, 8765)
        XCTAssertEqual(tunnelHost, "e315-47-208-216-108.ngrok.io")
        XCTAssertEqual(json, "{\"applinks\":{\"details\":[{\"appIds\":[\"team123.com.bundle.example\"]}],\"webcredentials\":{\"apps\":[\"team123.com.bundle.example\"]}}}")
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
                "pkill ngrok",
                "which ngrok",
                "ngrok http 123",
                "curl http://127.0.0.1:4040/api/tunnels --silent --max-time 0.1",
            ]
        )
        XCTAssertEqual(output, ["Add e315-47-208-216-108.ngrok.io to your app\'s entitlements file."])
        XCTAssertEqual(port, 123)
        XCTAssertEqual(tunnelHost, "e315-47-208-216-108.ngrok.io")
        XCTAssertEqual(json, "{\"iamjson\":34}")
        XCTAssertEqual(file, "example.json")
    }

    func testManualStrategyParsing() throws {
        let command = try Runner.parseAsRoot(["--app-ids", "com.1234", "blah", "--port", "8765"]) as? Runner
        XCTAssertEqual(command?.appIds, ["com.1234", "blah"])
        XCTAssertEqual(command?.port, 8765)
    }

    func testProjectFileStrategyParsing() throws {
        let command = try Runner.parseAsRoot(["--project-file", "blah.xcodeproj", "--scheme", "Scheme123"]) as? Runner
        XCTAssertEqual(command?.projectFile, "blah.xcodeproj")
        XCTAssertEqual(command?.scheme, "Scheme123")
        XCTAssertEqual(command?.port, 8080)

        XCTAssertThrowsError(try Runner.parseAsRoot(["--project-file", "blah.xcodeproj"]))
    }

    func testWorkspaceFileStrategyParsing() throws {
        let command = try Runner.parseAsRoot(["--workspace-file", "blah.xcworkspace", "--scheme", "Scheme123"]) as? Runner
        XCTAssertEqual(command?.workspaceFile, "blah.xcworkspace")
        XCTAssertEqual(command?.scheme, "Scheme123")
        XCTAssertEqual(command?.port, 8080)

        XCTAssertThrowsError(try Runner.parseAsRoot(["--workspace-file", "blah.xcworkspace"]))
        XCTAssertThrowsError(try Runner.parseAsRoot(["--scheme", "blah.xcworkspace"]))
    }

    func testJsonFileStrategyParsing() throws {
        let command = try Runner.parseAsRoot(["--json-file", "blah.json", "--entitlements-file", "Blah.entitlements"]) as? Runner
        XCTAssertEqual(command?.jsonFile, "blah.json")
        XCTAssertEqual(command?.entitlementsFile, "Blah.entitlements")
    }
}
