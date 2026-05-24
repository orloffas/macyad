import Foundation

public struct RcloneCommandBuilder {
    public static func remoteCreateCommand(configPath: String, remoteName: String) -> String {
        "rclone config create \(remoteName) yandex --config \(shellEscape(configPath))"
    }

    public static func syncArguments(for pair: SyncPair) -> [String] {
        ["sync", pair.localFolderDisplayPath, pair.remotePath]
    }

    public static func checkArguments(for pair: SyncPair) -> [String] {
        ["check", pair.localFolderDisplayPath, pair.remotePath, "--one-way"]
    }

    public static func pullArguments(for pair: SyncPair) -> [String] {
        ["copy", pair.remotePath, pair.localFolderDisplayPath]
    }

    private static func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
