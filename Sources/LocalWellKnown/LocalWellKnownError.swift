import Foundation

enum LocalWellKnownError: LocalizedError {
    case ngrokInstallationFailed
    case parsingMissingRequiredOption(option: String)
    case parsingMissingAppIdRetrievalOptions
    case shellFailure(exitStatus: Int32)

    var errorDescription: String? {
        switch self {
        case let .parsingMissingRequiredOption(option):
            return "--\(option) is required in this context"
        case .parsingMissingAppIdRetrievalOptions:
            return "One of the following options is required: --project-file, --workspace-file, --app-ids, --json-file"
        case .ngrokInstallationFailed:
            return "Unable to install ngrok via 'brew install --cask ngrok'. Try running installation separately"
        case .shellFailure:
            return nil
        }
    }
}
