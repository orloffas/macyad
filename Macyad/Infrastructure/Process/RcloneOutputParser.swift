import Foundation

public struct RcloneOutputParser {
    public static func differenceCount(_ stdout: String, stderr: String = "") -> Int? {
        let combinedOutput = stdout + "\n" + stderr
        let pattern = #"(?i)\b([0-9]+)\s+differences\s+found\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(combinedOutput.startIndex..<combinedOutput.endIndex, in: combinedOutput)
        guard let match = expression.firstMatch(in: combinedOutput, options: [], range: range),
              let captureRange = Range(match.range(at: 1), in: combinedOutput) else {
            return nil
        }

        return Int(combinedOutput[captureRange])
    }

    public static func containsRemoteChanges(_ stdout: String, stderr: String = "") -> Bool {
        (differenceCount(stdout, stderr: stderr) ?? 0) > 0
    }
}
