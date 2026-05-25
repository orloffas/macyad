import Foundation

public struct RcloneCommandBuilder {
    public static func remoteCreateCommand(configPath: String, remoteName: String) -> String {
        "rclone --config \(shellQuoted(configPath)) config create \(remoteName) yandex"
    }

    public static func syncArguments(for pair: SyncPair, configPath: String) -> [String] {
        withConfig(configPath, command: ["sync", pair.localFolderDisplayPath, pair.remotePath])
    }

    public static func syncArguments(for pair: SyncPair) -> [String] {
        ["sync", pair.localFolderDisplayPath, pair.remotePath]
    }

    public static func checkArguments(for pair: SyncPair, configPath: String) -> [String] {
        withConfig(configPath, command: ["check", pair.localFolderDisplayPath, pair.remotePath, "--one-way"])
    }

    public static func checkArguments(for pair: SyncPair) -> [String] {
        ["check", pair.localFolderDisplayPath, pair.remotePath, "--one-way"]
    }

    public static func pullArguments(for pair: SyncPair, configPath: String) -> [String] {
        withConfig(configPath, command: ["copy", pair.remotePath, pair.localFolderDisplayPath])
    }

    public static func pullArguments(for pair: SyncPair) -> [String] {
        ["copy", pair.remotePath, pair.localFolderDisplayPath]
    }

    private static func withConfig(_ configPath: String, command: [String]) -> [String] {
        ["--config", configPath] + command
    }

    private static func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
