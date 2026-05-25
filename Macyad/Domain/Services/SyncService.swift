import Foundation

public struct SyncService: Sendable {
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
        public let stderr: String

        public var errorDescription: String? {
            AppCopy.current.rcloneCommandFailed(command: command, exitCode: exitCode, stderr: stderr)
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
        try ensureSuccess(result, command: arguments)
    }

    public func check(_ pair: SyncPair) async throws -> Severity {
        let arguments = checkArguments(for: pair)
        let result = try await processClient.run(arguments)
        try ensureSuccess(result, command: arguments)
        return driftService.severityForCheck(stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode)
    }

    public func pull(_ pair: SyncPair) async throws {
        let arguments = pullArguments(for: pair)
        let result = try await processClient.run(arguments)
        try ensureSuccess(result, command: arguments)
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

    private func ensureSuccess(
        _ result: (stdout: String, stderr: String, exitCode: Int32),
        command: [String]
    ) throws {
        guard result.exitCode == 0 else {
            throw CommandFailedError(command: command, exitCode: result.exitCode, stderr: result.stderr)
        }
    }
}
