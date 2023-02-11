import XCTest
@testable import LocalWellKnown

final class LocalWellKnownTests: XCTestCase {
    func testManual() async throws {
        let jsonEncoder = JSONEncoder()

        var commands: [String] = []
        var output: [String] = []
        var port: UInt16?
        var tunnelHost: String?
        var json: String?

        let expectation = self.expectation(description: "Server run() called")

        Current.shell._run = { commands.append($0); return .init() }
        Current.shell.runAsyncStream = {
            commands.append($0)
            return .init {
                try jsonEncoder.encode(LocalWellKnown.SSHResponse(address: URL(string: "com.blah")!))
            }
        }
        Current.server.run = { portValue, host, jsonValue in
            port = portValue
            tunnelHost = host
            json = jsonValue
            expectation.fulfill()
        }
        Current.stdout._write = {
            output.append($0)
        }

        try await LocalWellKnown.run(
            strategy: .manual(appIds: ["com.1234"]),
            port: 8765,
            entitlementsFile: nil
        ) { _ in }

        wait(for: [expectation], timeout: 0.1)

        XCTAssertEqual(
            commands, ["ps -o pid -o command | grep -E \'^\\s*\\d+ ssh -R 80:localhost:8765 localhost.run\' | awk \"{print \\$1}\" | xargs kill", "ssh-keygen -F localhost.run || ssh-keyscan -H localhost.run >> ~/.ssh/known_hosts", "ssh -R 80:localhost:8765 localhost.run -- --output json"]
        )
        XCTAssertEqual(output, ["", "Add com.blah to your app\'s entitlements file.", "\n"])
        XCTAssertEqual(port, 8765)
        XCTAssertEqual(tunnelHost, "com.blah")
        XCTAssertEqual(json, "{\"applinks\":[\"details\":[{\"appIds\":[\"com.1234\"]}],\"webcredentials\":{\"apps\":[\"com.1234\"]}")
    }
}
