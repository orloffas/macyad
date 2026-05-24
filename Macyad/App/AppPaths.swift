import Foundation

struct AppPaths: Sendable {
    let appSupportRoot: URL
    let workspaceRoot: URL
    let pairsFile: URL
    let preferencesFile: URL
    let activityFile: URL

    static func live() throws -> AppPaths {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Macyad", isDirectory: true)
        return makeForTesting(rootURL: base)
    }

    static func makeForTesting(rootURL: URL) -> AppPaths {
        AppPaths(
            appSupportRoot: rootURL,
            workspaceRoot: rootURL.appendingPathComponent("Workspace", isDirectory: true),
            pairsFile: rootURL.appendingPathComponent("pairs.json"),
            preferencesFile: rootURL.appendingPathComponent("preferences.json"),
            activityFile: rootURL.appendingPathComponent("activity.json")
        )
    }
}
