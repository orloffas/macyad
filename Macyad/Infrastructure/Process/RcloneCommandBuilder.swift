import Foundation

public struct RcloneCommandBuilder {
    public static func remoteCreateCommand(remoteName: String) -> String {
        "rclone config create \(remoteName) yandex"
    }

    public static func remoteCreateCommand(configPath _: String, remoteName: String) -> String {
        remoteCreateCommand(remoteName: remoteName)
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

}
