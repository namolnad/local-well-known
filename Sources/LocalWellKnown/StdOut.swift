struct StdOut: TextOutputStream {
    var writeToStream: (String) -> Void

    func write(_ string: String) {
        writeToStream(string)
    }
}

extension StdOut {
    static let live: Self = .init { print($0) }
}
