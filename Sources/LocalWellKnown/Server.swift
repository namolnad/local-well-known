import Foundation
import Swifter

struct Server {
    var run: (UInt16, String, String) throws -> Void
}

extension Server {
    static let live: Self = .init { port, remoteHost, json in
        let server = HttpServer()

        server.middleware.append { request in
            print("[INFO] \(request.address ?? "unknown address") -> \(request.method) -> \(request.path)", to: &Current.stdout)
            return nil
        }

        server.notFoundHandler = { _ in .movedPermanently("https://example.com/404") }

        server.GET["/apple-app-site-association", "/.well-known/apple-app-site-association"] = { _ in
            .ok(.text(json))
        }

        let semaphore = DispatchSemaphore(value: 0)
        do {
            try server.start(port)

            print("Hosting apple-app-site-assocation on localhost:\(port) and \(remoteHost)", to: &Current.stdout)

            semaphore.wait()
        } catch {
            print("Server start error: \(error)", to: &Current.stdout)
            semaphore.signal()
        }
    }
}
