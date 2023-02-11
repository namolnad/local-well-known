import Foundation

enum ParserError: LocalizedError {
    case missingRequiredOption(option: String)
    case missingAppIdRetrievalOptions

    var errorDescription: String? {
        switch self {
        case let .missingRequiredOption(option):
            return "--\(option) is required in this context"
        case .missingAppIdRetrievalOptions:
            return "One of the following options is required: --app-ids, --project-file, --workspace-file, --json"
        }
    }
}
