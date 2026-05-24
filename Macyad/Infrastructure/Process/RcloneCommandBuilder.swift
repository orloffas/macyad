import Foundation

struct RcloneCommandBuilder {
    static func remoteCreateCommand(configPath: String, remoteName: String) -> String {
        "rclone config create \(remoteName) yandex --config \(shellEscape(configPath))"
    }

    private static func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
