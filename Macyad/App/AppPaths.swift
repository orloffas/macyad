import Foundation

struct AppPaths: Sendable {
    let appSupportRoot: URL
    let workspaceRoot: URL
    let pairsFile: URL
    let preferencesFile: URL
    let activityFile: URL

    static func live(fileManager: FileManager = .default) throws -> AppPaths {
        let appSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try live(appSupportDirectory: appSupportDirectory, fileManager: fileManager)
    }

    static func live(appSupportDirectory: URL, fileManager: FileManager = .default) throws -> AppPaths {
        let appSupportRoot = appSupportDirectory.appendingPathComponent("Macyad", isDirectory: true)
        let paths = makeForTesting(rootURL: appSupportRoot)

        try fileManager.createDirectory(at: paths.appSupportRoot, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: paths.workspaceRoot, withIntermediateDirectories: true, attributes: nil)

        return paths
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
