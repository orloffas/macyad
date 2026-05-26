import Foundation

public struct RcloneConfigInspector: Sendable {
    public let configURL: URL

    public init(configURL: URL) {
        self.configURL = configURL
    }

    public func remoteNames() -> [String] {
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return []
        }

        let matches = contents.matches(of: /\[(.+?)\]/)
        return matches.compactMap { match in
            let value = String(match.output.1).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }
}
