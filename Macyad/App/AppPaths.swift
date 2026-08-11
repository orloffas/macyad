import Foundation

public struct AppPaths: Sendable {
    public let appSupportRoot: URL
    public let workspaceRoot: URL
    /// What the UI shows for the workspace. Same as `workspaceRoot` everywhere
    /// except the seeded screenshot runs, where the real path is a throwaway
    /// directory under `/var/folders/…` that would only confuse a reader of
    /// the README.
    public var workspaceDisplayPath: String
    public let rcloneFiltersDirectory: URL
    public let rcloneConfigFile: URL
    public let conflictStateDirectory: URL
    public let pairsFile: URL
    public let accountsFile: URL
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
        let appSupportRoot = appSupportDirectory.appendingPathComponent("MacYaD", isDirectory: true)
        let paths = makeForTesting(rootURL: appSupportRoot)

        try fileManager.createDirectory(at: paths.appSupportRoot, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: paths.workspaceRoot, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(
            at: paths.rcloneConfigFile.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try fileManager.createDirectory(at: paths.rcloneFiltersDirectory, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: paths.conflictStateDirectory, withIntermediateDirectories: true, attributes: nil)

        return paths
    }

    public static func makeForTesting(rootURL: URL) -> AppPaths {
        let workspaceRoot = rootURL.appendingPathComponent("Workspace", isDirectory: true)
        return AppPaths(
            appSupportRoot: rootURL,
            workspaceRoot: workspaceRoot,
            workspaceDisplayPath: workspaceRoot.path,
            rcloneFiltersDirectory: rootURL.appendingPathComponent("rclone", isDirectory: true).appendingPathComponent("filters", isDirectory: true),
            rcloneConfigFile: rootURL.appendingPathComponent("rclone", isDirectory: true).appendingPathComponent("rclone.conf"),
            conflictStateDirectory: rootURL.appendingPathComponent("conflicts", isDirectory: true),
            pairsFile: rootURL.appendingPathComponent("pairs.json"),
            accountsFile: rootURL.appendingPathComponent("accounts.json"),
            preferencesFile: rootURL.appendingPathComponent("preferences.json"),
            activityFile: rootURL.appendingPathComponent("activity.json")
        )
    }
}
