import Foundation

public struct SyncService: Sendable {
    public struct CommandFailedError: Error, LocalizedError, Sendable {
        public let command: [String]
        public let exitCode: Int32
        public let stderr: String

        public var errorDescription: String? {
            let stderrSuffix = stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : ": \(stderr)"
            return "rclone \(command.joined(separator: " ")) завершился с кодом \(exitCode)\(stderrSuffix)"
        }
    }

    public let processClient: RcloneProcessRunning
    public let driftService: DriftService

    public init(processClient: RcloneProcessRunning, driftService: DriftService = DriftService()) {
        self.processClient = processClient
        self.driftService = driftService
    }

    public func push(_ pair: SyncPair) async throws {
        let arguments = RcloneCommandBuilder.syncArguments(for: pair)
        let result = try await processClient.run(arguments)
        try ensureSuccess(result, command: arguments)
    }

    public func check(_ pair: SyncPair) async throws -> Severity {
        let arguments = RcloneCommandBuilder.checkArguments(for: pair)
        let result = try await processClient.run(arguments)
        try ensureSuccess(result, command: arguments)
        return driftService.severityForCheck(stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode)
    }

    public func pull(_ pair: SyncPair) async throws {
        let arguments = RcloneCommandBuilder.pullArguments(for: pair)
        let result = try await processClient.run(arguments)
        try ensureSuccess(result, command: arguments)
    }

    private func ensureSuccess(
        _ result: (stdout: String, stderr: String, exitCode: Int32),
        command: [String]
    ) throws {
        guard result.exitCode == 0 else {
            throw CommandFailedError(command: command, exitCode: result.exitCode, stderr: result.stderr)
        }
    }
}
