import Foundation

struct Environment {
    var server: Server = .live
    var shell: Shell = .live
    var print: (String) -> Void = { Swift.print($0) }
    var contentsOfFile: (String) throws -> String = { try .init(contentsOf: URL(fileURLWithPath: $0)) }
    var makeInterruptHandler: (@escaping () -> Void) -> DispatchSourceProtocol = { handler in
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
