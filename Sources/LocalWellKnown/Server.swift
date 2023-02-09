import Foundation
import Swifter

struct Server {
    let port: UInt16
    let appIds: [String]

    func run() throws {
        let server = HttpServer()

        server.middleware.append { request in
            print("[INFO] \(request.address ?? "unknown address") -> \(request.method) -> \(request.path)")
            return nil
        }

        server.notFoundHandler = { _ in .movedPermanently("https://example.com/404") }

        server.GET["/apple-app-site-association", "/.well-known/apple-app-site-association"] = { _ in
            .ok(.json([
                "applinks": ["details": [["appIDs": appIds]]],
                "webcredentials": ["apps": appIds],
            ]))
        }

        let semaphore = DispatchSemaphore(value: 0)
        do {
            try server.start(port)
            print("Server has started on port: (\(try server.port()))")

            semaphore.wait()
        } catch {
            print("Server start error: \(error)")
            semaphore.signal()
        }
    }
}
