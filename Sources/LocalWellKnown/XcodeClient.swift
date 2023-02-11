import Foundation

struct XcodeClient {
    var getAppIds: (JSONDecoder, String, String, String) throws -> [String]
}

extension XcodeClient {
    static let live: Self = .init { decoder, strategy, file, scheme in
        let data = try Shell.run("xcrun xcodebuild -quiet -showBuildSettings  -json -\(strategy) '\(file)' -scheme '\(scheme)' 2> /dev/null")
        let response = try decoder.decode(Response.self, from: data)
        guard let appId = response.appId else { throw Error.unableToGetAppId }
        return [appId]
    }
}

private extension XcodeClient {
    enum Error: Swift.Error {
        case unableToGetAppId
    }

    struct Response: Decodable {
        var appId: String? {
            actionSettings
                .first { $0.action == "build" }
                .map(\.buildSettings)
                .map { "\($0.teamId).\($0.bundleId)" }
        }

        private let actionSettings: [ActionSettings]

        init(from decoder: Decoder) throws {
            self.actionSettings = try .init(from: decoder)
        }

        struct ActionSettings: Decodable {
            let action: String
            let buildSettings: Settings

            struct Settings: Decodable {
                private enum CodingKeys: String, CodingKey {
                    case teamId = "DEVELOPMENT_TEAM"
                    case bundleId = "PRODUCT_BUNDLE_IDENTIFIER"
                }

                let teamId: String
                let bundleId: String
            }
        }
    }
}
