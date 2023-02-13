import Foundation

enum LocalWellKnownError: LocalizedError {
    case parsingMissingRequiredOption(option: String)
    case parsingMissingAppIdRetrievalOptions
    case shellFailure(exitStatus: Int32)
    case sshKnownHostMissing(host: String)

    var errorDescription: String? {
        switch self {
        case let .parsingMissingRequiredOption(option):
            return "--\(option) is required in this context"
        case .parsingMissingAppIdRetrievalOptions:
            return "One of the following options is required: --project-file, --workspace-file, --app-ids, --json-file"
        case .shellFailure:
            return nil
        case let .sshKnownHostMissing(host):
            return "\(host) not present in ~/.ssh/known_hosts. Add host fingerprint manually or enable auto-trust-ssh"
        }
    }
}
