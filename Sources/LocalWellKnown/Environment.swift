import Foundation

struct Environment {
    var xcodeClient: XcodeClient = .live
    var entitlementsClient: EntitlementsClient = .live
    var stdout: StdOut = .live
    var serverClient: ServerClient = .live
    var sshClient: SSHClient = .live
    var contentsOfFile: (String) throws -> String = { try .init(contentsOf: URL(fileURLWithPath: $0)) }
    var makeInterruptHandler: (@escaping () -> Void) -> DispatchSourceSignal = { handler in
        signal(SIGINT, SIG_IGN)

        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler(handler: handler)

        return source
    }
}

#if DEBUG
var Current = Environment()
#else
let Current = Environment()
#endif
