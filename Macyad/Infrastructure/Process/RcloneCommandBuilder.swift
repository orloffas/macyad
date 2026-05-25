import Foundation

public struct RcloneCommandBuilder {
    public static func remoteCreateCommand(configPath: String, remoteName: String) -> String {
        "rclone --config \(shellQuoted(configPath)) config create \(remoteName) yandex"
    }

    public static func syncArguments(for pair: SyncPair, configPath: String) -> [String] {
        withConfig(configPath, command: syncArguments(for: pair))
    }

    public static func syncArguments(for pair: SyncPair) -> [String] {
        withExcludes(
            ["sync", pair.localFolderDisplayPath, pair.remotePath],
            patterns: pair.syncExcludes
        )
    }

    public static func checkArguments(for pair: SyncPair, configPath: String) -> [String] {
        withConfig(configPath, command: checkArguments(for: pair))
    }

    public static func checkArguments(for pair: SyncPair) -> [String] {
        withExcludes(
            ["check", pair.localFolderDisplayPath, pair.remotePath, "--one-way"],
            patterns: pair.allCheckExcludes
        )
    }

    public static func pullArguments(for pair: SyncPair, configPath: String) -> [String] {
        withConfig(configPath, command: pullArguments(for: pair))
    }

    public static func pullArguments(for pair: SyncPair) -> [String] {
        withExcludes(
            ["copy", pair.remotePath, pair.localFolderDisplayPath],
            patterns: pair.syncExcludes
        )
    }

    private static func withConfig(_ configPath: String, command: [String]) -> [String] {
        ["--config", configPath] + command
    }

    private static func withExcludes(_ command: [String], patterns: [String]) -> [String] {
        command + patterns.flatMap { ["--exclude", $0] }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
