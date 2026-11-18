import Foundation

public struct RcloneCommandBuilder {
    /// `script/connect_yandex.py`, copied into the app bundle by `project.yml`.
    public static var connectScriptPath: String {
        Bundle.main.path(forResource: "connect_yandex", ofType: "py") ?? "connect_yandex.py"
    }

    // Yandex answers 410 GoneError to rclone's built-in OAuth client, so `rclone config create/reconnect`
    // cannot produce a working remote; the script connects through the user's own Yandex OAuth app.
    public static func remoteCreateCommand(configPath: String, remoteName: String, scriptPath: String = connectScriptPath) -> String {
        "python3 \(shellQuoted(scriptPath)) --config \(shellQuoted(configPath)) --remote \(shellQuoted(remoteName))"
    }

    public static func remoteReconnectCommand(configPath: String, remoteName: String, scriptPath: String = connectScriptPath) -> String {
        remoteCreateCommand(configPath: configPath, remoteName: remoteName, scriptPath: scriptPath)
    }

    public static func remoteDeleteCommand(configPath: String, remoteName: String) -> String {
        "rclone --config \(shellQuoted(configPath)) config delete \(shellQuoted(remoteName))"
    }

    public static func syncArguments(for pair: SyncPair, configPath: String, excludeFilePath: String? = nil) -> [String] {
        withConfig(configPath, command: syncArguments(for: pair, excludeFilePath: excludeFilePath))
    }

    public static func syncArguments(for pair: SyncPair, excludeFilePath: String? = nil) -> [String] {
        withExcludes(
            ["sync", pair.localFolderDisplayPath, pair.remotePath],
            patterns: pair.allSyncExcludes,
            excludeFilePath: excludeFilePath
        )
    }

    public static func checkArguments(for pair: SyncPair, configPath: String, excludeFilePath: String? = nil) -> [String] {
        withConfig(configPath, command: checkArguments(for: pair, excludeFilePath: excludeFilePath))
    }

    public static func checkArguments(for pair: SyncPair, excludeFilePath: String? = nil) -> [String] {
        withExcludes(
            ["check", pair.localFolderDisplayPath, pair.remotePath, "--one-way"],
            patterns: pair.allCheckExcludes,
            excludeFilePath: excludeFilePath
        )
    }

    public static func pullArguments(for pair: SyncPair, configPath: String, excludeFilePath: String? = nil) -> [String] {
        withConfig(configPath, command: pullArguments(for: pair, excludeFilePath: excludeFilePath))
    }

    public static func pullArguments(for pair: SyncPair, excludeFilePath: String? = nil) -> [String] {
        withExcludes(
            ["copy", pair.remotePath, pair.localFolderDisplayPath],
            patterns: pair.allSyncExcludes,
            excludeFilePath: excludeFilePath
        )
    }

    public static func lsjsonArguments(path: String, configPath: String? = nil, excludeFilePath: String? = nil) -> [String] {
        let command = withExcludes(
            ["lsjson", path, "-R", "--files-only", "--hash", "--hash-type", "MD5"],
            patterns: [],
            excludeFilePath: excludeFilePath
        )

        guard let configPath else {
            return command
        }

        return withConfig(configPath, command: command)
    }

    public static func copyToArguments(sourcePath: String, destinationPath: String, configPath: String? = nil) -> [String] {
        let command = ["copyto", sourcePath, destinationPath]
        guard let configPath else {
            return command
        }

        return withConfig(configPath, command: command)
    }

    public static func deleteFileArguments(path: String, configPath: String? = nil) -> [String] {
        let command = ["deletefile", path]
        guard let configPath else {
            return command
        }

        return withConfig(configPath, command: command)
    }

    private static func withConfig(_ configPath: String, command: [String]) -> [String] {
        ["--config", configPath] + command
    }

    private static func withExcludes(_ command: [String], patterns: [String], excludeFilePath: String?) -> [String] {
        if let excludeFilePath {
            return command + ["--exclude-from", excludeFilePath]
        }

        return command + patterns.flatMap { ["--exclude", $0] }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
