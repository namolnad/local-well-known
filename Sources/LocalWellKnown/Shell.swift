import Foundation

struct Shell {
    var _run: (String) throws -> Data
    var runAsyncStream: (String) -> AsyncThrowingStream<Data, Error>

    @discardableResult
    func run(_ command: String) throws -> Data {
        try _run(command)
    }
}

extension Shell {
    static let live: Self = {
        let task = { command in
            let task = Process()
            let pipe = Pipe()

            task.standardOutput = pipe
            task.standardError = pipe
            task.arguments = ["zsh", "-c", command]
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.standardInput = nil

            return (task, pipe)
        }

        return .init(
            _run: { command in
                let (task, pipe) = task(command)

                try task.run()
                task.waitUntilExit()

                if task.terminationStatus != 0 {
                    throw LocalWellKnownError.shellFailure(exitStatus: task.terminationStatus)
                }

                return pipe.fileHandleForReading.readDataToEndOfFile()
            },
            runAsyncStream: { command in
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
        )
    }()
}
