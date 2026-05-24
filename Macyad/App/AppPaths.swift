import Foundation

public struct AppPaths: Sendable {
    public let appSupportRoot: URL
    public let workspaceRoot: URL
    public let pairsFile: URL
    public let preferencesFile: URL
    public let activityFile: URL

    public static func live(fileManager: FileManager = .default) throws -> AppPaths {
        let appSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try live(appSupportDirectory: appSupportDirectory, fileManager: fileManager)
    }

    public static func live(appSupportDirectory: URL, fileManager: FileManager = .default) throws -> AppPaths {
        let appSupportRoot = appSupportDirectory.appendingPathComponent("Macyad", isDirectory: true)
        let paths = makeForTesting(rootURL: appSupportRoot)

        try fileManager.createDirectory(at: paths.appSupportRoot, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: paths.workspaceRoot, withIntermediateDirectories: true, attributes: nil)

        return paths
    }

    public static func makeForTesting(rootURL: URL) -> AppPaths {
        AppPaths(
            appSupportRoot: rootURL,
            workspaceRoot: rootURL.appendingPathComponent("Workspace", isDirectory: true),
            pairsFile: rootURL.appendingPathComponent("pairs.json"),
            preferencesFile: rootURL.appendingPathComponent("preferences.json"),
            activityFile: rootURL.appendingPathComponent("activity.json")
        )
    }
}
