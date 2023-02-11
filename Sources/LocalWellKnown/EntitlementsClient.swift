import Foundation

struct EntitlementsClient {
    var setOrAddEntitlementToFile: (Int, String, String, String) throws -> Void
}

extension EntitlementsClient {
    static let live: Self = {
        return .init { index, entitlement, domain, file in
            let makeCommand: (String, String?) -> String = { command, type in
                "/usr/libexec/PlistBuddy -c '\(command) :com.apple.developer.associated-domains:\(index) \(type.map { $0 + " " } ?? "")\(entitlement):\(domain)' \(file)"
            }
            try Shell.run("\(makeCommand("set", nil)) || \(makeCommand("add", "string"))")
        }
    }()
}
