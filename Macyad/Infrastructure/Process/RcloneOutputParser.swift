import Foundation

struct RcloneOutputParser {
    static func containsRemoteChanges(_ stdout: String) -> Bool {
        stdout.contains("NOTICE") || stdout.contains("Transferred:")
    }
}
