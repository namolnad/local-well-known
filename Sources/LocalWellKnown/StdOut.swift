struct StdOut: TextOutputStream {
    var _write: (String) -> Void

    func write(_ string: String) {
        _write(string)
    }
}

extension StdOut {
    static let live: Self = .init { print($0) }
}
