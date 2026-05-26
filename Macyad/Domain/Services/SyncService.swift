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
        public let differenceCount: Int?

        public init(severity: Severity, log: RcloneCommandLog, differenceCount: Int?) {
            self.severity = severity
            self.log = log
            self.differenceCount = differenceCount
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

        public var summaryDescription: String {
            AppCopy.current.rcloneCommandSummary(exitCode: exitCode, stderr: stderr)
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
    public let excludeFileStore: RcloneExcludeFilePreparing?

    public init(
        processClient: RcloneProcessRunning,
        driftService: DriftService = DriftService(),
        configPath: String? = nil,
        localFolderInspector: LocalFolderInspecting = FileManagerLocalFolderInspector(),
        excludeFileStore: RcloneExcludeFilePreparing? = nil
    ) {
        self.processClient = processClient
        self.driftService = driftService
        self.configPath = configPath
        self.localFolderInspector = localFolderInspector
        self.excludeFileStore = excludeFileStore
    }

    public func push(_ pair: SyncPair) async throws {
        guard try localFolderInspector.containsUserVisibleContent(
            atPath: pair.localFolderDisplayPath,
            excludedPatterns: pair.syncExcludes
        ) else {
            throw LocalFolderEmptyPushBlockedError(
                pairName: pair.name,
                localFolderPath: pair.localFolderDisplayPath,
                remotePath: pair.remotePath
            )
        }

        let arguments = try syncArguments(for: pair)
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
        let arguments = try checkArguments(for: pair)
        let result = try await processClient.run(arguments)
        let log = RcloneCommandLog(
            command: arguments,
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode
        )
        let differenceCount = RcloneOutputParser.differenceCount(result.stdout, stderr: result.stderr)
        let disposition = driftService.dispositionForCheck(stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode)
        if disposition == .alarm {
            throw CommandFailedError(
                command: log.command,
                exitCode: log.exitCode,
                stdout: log.stdout,
                stderr: log.stderr
            )
        }

        return CheckOutcome(
            severity: disposition == .warning ? .warning : .healthy,
            log: log,
            differenceCount: differenceCount
        )
    }

    public func pull(_ pair: SyncPair) async throws {
        let arguments = try pullArguments(for: pair)
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

    private func syncArguments(for pair: SyncPair) throws -> [String] {
        let excludeFilePath = try excludeFileStore?.prepareExcludeFile(for: pair, mode: .sync)
        guard let configPath else {
            return RcloneCommandBuilder.syncArguments(for: pair, excludeFilePath: excludeFilePath)
        }

        return RcloneCommandBuilder.syncArguments(for: pair, configPath: configPath, excludeFilePath: excludeFilePath)
    }

    private func checkArguments(for pair: SyncPair) throws -> [String] {
        let excludeFilePath = try excludeFileStore?.prepareExcludeFile(for: pair, mode: .check)
        guard let configPath else {
            return RcloneCommandBuilder.checkArguments(for: pair, excludeFilePath: excludeFilePath)
        }

        return RcloneCommandBuilder.checkArguments(for: pair, configPath: configPath, excludeFilePath: excludeFilePath)
    }

    private func pullArguments(for pair: SyncPair) throws -> [String] {
        let excludeFilePath = try excludeFileStore?.prepareExcludeFile(for: pair, mode: .sync)
        guard let configPath else {
            return RcloneCommandBuilder.pullArguments(for: pair, excludeFilePath: excludeFilePath)
        }

        return RcloneCommandBuilder.pullArguments(for: pair, configPath: configPath, excludeFilePath: excludeFilePath)
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
