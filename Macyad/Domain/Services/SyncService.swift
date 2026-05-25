import Foundation

public struct SyncService: Sendable {
    public struct RcloneCommandLog: Equatable, Sendable {
        public let command: [String]
        public let stdout: String
        public let stderr: String
        public let exitCode: Int32

        public init(command: [String], stdout: String, stderr: String, exitCode: Int32) {
            self.command = command
            self.stdout = stdout
            self.stderr = stderr
            self.exitCode = exitCode
        }

        public var detailedDescription: String {
            AppCopy.current.rcloneCommandLog(
                command: command,
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr
            )
        }
    }

    public struct CheckOutcome: Equatable, Sendable {
        public let severity: Severity
        public let log: RcloneCommandLog

        public init(severity: Severity, log: RcloneCommandLog) {
            self.severity = severity
            self.log = log
        }
    }

    public struct LocalFolderEmptyPushBlockedError: Error, LocalizedError, Sendable {
        public let pairName: String
        public let localFolderPath: String
        public let remotePath: String

        public var errorDescription: String? {
            AppCopy.current.localFolderEmptyPushBlocked
        }
    }

    public struct CommandFailedError: Error, LocalizedError, Sendable {
        public let command: [String]
        public let exitCode: Int32
        public let stdout: String
        public let stderr: String

        public init(command: [String], exitCode: Int32, stdout: String = "", stderr: String) {
            self.command = command
            self.exitCode = exitCode
            self.stdout = stdout
            self.stderr = stderr
        }

        public var errorDescription: String? {
            AppCopy.current.rcloneCommandFailed(command: command, exitCode: exitCode, stderr: stderr)
        }

        public var detailedDescription: String {
            AppCopy.current.rcloneCommandLog(
                command: command,
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr
            )
        }
    }

    public let processClient: RcloneProcessRunning
    public let driftService: DriftService
    public let configPath: String?
    public let localFolderInspector: LocalFolderInspecting

    public init(
        processClient: RcloneProcessRunning,
        driftService: DriftService = DriftService(),
        configPath: String? = nil,
        localFolderInspector: LocalFolderInspecting = FileManagerLocalFolderInspector()
    ) {
        self.processClient = processClient
        self.driftService = driftService
        self.configPath = configPath
        self.localFolderInspector = localFolderInspector
    }

    public func push(_ pair: SyncPair) async throws {
        guard try localFolderInspector.containsUserVisibleContent(atPath: pair.localFolderDisplayPath) else {
            throw LocalFolderEmptyPushBlockedError(
                pairName: pair.name,
                localFolderPath: pair.localFolderDisplayPath,
                remotePath: pair.remotePath
            )
        }

        let arguments = syncArguments(for: pair)
        let result = try await processClient.run(arguments)
        try ensureSuccess(
            RcloneCommandLog(
                command: arguments,
                stdout: result.stdout,
                stderr: result.stderr,
                exitCode: result.exitCode
            )
        )
    }

    public func check(_ pair: SyncPair) async throws -> CheckOutcome {
        let arguments = checkArguments(for: pair)
        let result = try await processClient.run(arguments)
        let log = RcloneCommandLog(
            command: arguments,
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode
        )
        try ensureSuccess(log)
        return CheckOutcome(
            severity: driftService.severityForCheck(stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode),
            log: log
        )
    }

    public func pull(_ pair: SyncPair) async throws {
        let arguments = pullArguments(for: pair)
        let result = try await processClient.run(arguments)
        try ensureSuccess(
            RcloneCommandLog(
                command: arguments,
                stdout: result.stdout,
                stderr: result.stderr,
                exitCode: result.exitCode
            )
        )
    }

    private func syncArguments(for pair: SyncPair) -> [String] {
        guard let configPath else {
            return RcloneCommandBuilder.syncArguments(for: pair)
        }

        return RcloneCommandBuilder.syncArguments(for: pair, configPath: configPath)
    }

    private func checkArguments(for pair: SyncPair) -> [String] {
        guard let configPath else {
            return RcloneCommandBuilder.checkArguments(for: pair)
        }

        return RcloneCommandBuilder.checkArguments(for: pair, configPath: configPath)
    }

    private func pullArguments(for pair: SyncPair) -> [String] {
        guard let configPath else {
            return RcloneCommandBuilder.pullArguments(for: pair)
        }

        return RcloneCommandBuilder.pullArguments(for: pair, configPath: configPath)
    }

    private func ensureSuccess(_ log: RcloneCommandLog) throws {
        guard log.exitCode == 0 else {
            throw CommandFailedError(
                command: log.command,
                exitCode: log.exitCode,
                stdout: log.stdout,
                stderr: log.stderr
            )
        }
    }
}
