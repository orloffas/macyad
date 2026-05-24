public struct DriftService: Sendable {
    public init() {}

    public func severityForCheck(stdout: String, stderr: String, exitCode: Int32) -> Severity {
        guard exitCode == 0 else {
            return .alarm
        }

        return RcloneOutputParser.containsRemoteChanges(stdout, stderr: stderr) ? .warning : .healthy
    }
}
