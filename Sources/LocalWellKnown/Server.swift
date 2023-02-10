import Foundation
import Swifter

struct Server {
    let json: String

    func run(port: UInt16, remoteHost: String) throws {
        let server = HttpServer()

        server.middleware.append { request in
            print("[INFO] \(request.address ?? "unknown address") -> \(request.method) -> \(request.path)")
            return nil
        }

        server.notFoundHandler = { _ in .movedPermanently("https://example.com/404") }

        server.GET["/apple-app-site-association", "/.well-known/apple-app-site-association"] = { _ in
            .ok(.text(json))
        }

        let semaphore = DispatchSemaphore(value: 0)
        do {
            try server.start(port)

            print("Hosting apple-app-site-assocation on localhost:\(port) and \(remoteHost)")

            semaphore.wait()
        } catch {
            print("Server start error: \(error)")
            semaphore.signal()
        }
    }
}
