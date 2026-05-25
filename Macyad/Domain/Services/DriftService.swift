public struct DriftService: Sendable {
    public enum CheckDisposition: Sendable {
        case healthy
        case warning
        case alarm
    }

    public init() {}

    public func severityForCheck(stdout: String, stderr: String, exitCode: Int32) -> Severity {
        switch dispositionForCheck(stdout: stdout, stderr: stderr, exitCode: exitCode) {
        case .healthy:
            return .healthy
        case .warning:
            return .warning
        case .alarm:
            return .alarm
        }
    }

    public func dispositionForCheck(stdout: String, stderr: String, exitCode: Int32) -> CheckDisposition {
        if let differenceCount = RcloneOutputParser.differenceCount(stdout, stderr: stderr) {
            if differenceCount > 0 {
                return .warning
            }

            if exitCode == 0 {
                return .healthy
            }
        }

        return exitCode == 0 ? .healthy : .alarm
    }
}
