import Foundation

public struct RcloneOutputParser {
    public static func containsRemoteChanges(_ stdout: String, stderr: String = "") -> Bool {
        let combinedOutput = stdout + "\n" + stderr
        return combinedOutput.contains("NOTICE")
            || combinedOutput.contains("Transferred:")
            || combinedOutput.localizedCaseInsensitiveContains("differences found")
    }
}
