import Foundation

struct SSHClient {
    var addKnownHostIfNeeded: () throws -> Void
    var startRemoteTunnel: (JSONDecoder, UInt16) async throws -> Response
    var cleanup: (UInt16) -> Void
}

extension SSHClient {
    static var live: Self = {
        let remoteHost = "localhost.run"
        let sshCommand: (UInt16) -> String = { port in
            "ssh -R 80:localhost:\(port) \(remoteHost)"
        }
        return .init(
            addKnownHostIfNeeded: {
                try Shell.run("ssh-keygen -F \(remoteHost) || ssh-keyscan \(remoteHost) >> ~/.ssh/known_hosts")
            },
            startRemoteTunnel: { decoder, port in
                for try await data in Shell.runAsyncStream("\(sshCommand(port)) -- --output json") {
                    guard let response = try? decoder.decode(SSHClient.Response.self, from: data) else {
                        continue
                    }
                    return response
                }
                throw Error.unexpectedLoopExit
            },
            cleanup: { port in
                do {
                    try Shell.run("ps -o pid -o command | grep -E '^\\s*\\d+ \(sshCommand(port))' | awk \"{print \\$1}\" | xargs kill")
                } catch {}
            }
        )
    }()
}

extension SSHClient {
    struct Response: Decodable {
        let address: URL
    }

    private enum Error: Swift.Error {
        case unexpectedLoopExit
    }
}
