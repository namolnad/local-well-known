import Foundation

//
//        if throwOnError, task.terminationStatus != 0 {
//            throw MyError.blah2
//        }
//
enum Shell {
//    @discardableResult
//    static func run(_ command: String) throws -> Data {
//        let (task, pipe) = task(command)
//
//        try task.run()
//        task.waitUntilExit()
//
//        return pipe.fileHandleForReading.readDataToEndOfFile()
//    }

    @discardableResult
    static func runAsyncStream(_ command: String) -> AsyncThrowingStream<Data, Error> {
        let (task, pipe) = task(command)

        return .init { continuation in
            pipe.fileHandleForReading.readabilityHandler = { handle in
                guard case let data = handle.availableData, !data.isEmpty else {
                    continuation.finish()
                    handle.readabilityHandler = nil
                    return
                }
                continuation.yield(data)
            }
            do {
                try task.run()
            } catch {
                continuation.finish(throwing: error)
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        }
    }

    @discardableResult
    static func runAsync(_ command: String) async throws -> Data {
        let (task, pipe) = task(command)

        return try await withCheckedThrowingContinuation { continuation in
            pipe.fileHandleForReading.readabilityHandler = { handle in
                guard case let data = handle.availableData, !data.isEmpty else {
                    continuation.resume(returning: .init())
                    handle.readabilityHandler = nil
                    return
                }

                continuation.resume(returning: data)
                handle.readabilityHandler = nil
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        }
    }

    private static func task(_ command: String) -> (Process, Pipe) {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["zsh", "-c", command]
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.standardInput = nil

        return (task, pipe)
    }
}
