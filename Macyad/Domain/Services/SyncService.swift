import Foundation

public struct SyncService: Sendable {
    public enum ExecutionMode: Sendable {
        case manual
        case scheduled
    }

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

    public struct OperationOutcome: Equatable, Sendable {
        public let severity: Severity
        public let summary: String
        public let details: String?
        public let differenceCount: Int?
        public let shouldUpdateLastSync: Bool
        public let updatedBaseline: Bool

        public init(
            severity: Severity,
            summary: String,
            details: String?,
            differenceCount: Int? = nil,
            shouldUpdateLastSync: Bool = false,
            updatedBaseline: Bool = false
        ) {
            self.severity = severity
            self.summary = summary
            self.details = details
            self.differenceCount = differenceCount
            self.shouldUpdateLastSync = shouldUpdateLastSync
            self.updatedBaseline = updatedBaseline
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

    private struct BaselinePreparation {
        let baseline: PairConflictBaselineState
        let analysis: PairConflictPlanner.Analysis
    }

    private actor NoopPairConflictStateStore: PairConflictStateStoring {
        func load(pairID: UUID) async throws -> PairConflictBaselineState? { nil }
        func save(_ state: PairConflictBaselineState) async throws {}
        func remove(pairID: UUID) async throws {}
    }

    public let processClient: RcloneProcessRunning
    public let driftService: DriftService
    public let configPath: String?
    public let localFolderInspector: LocalFolderInspecting
    public let excludeFileStore: RcloneExcludeFilePreparing?
    public let snapshotProvider: PairSnapshotProviding
    public let baselineRepository: PairConflictStateStoring
    public let planner: PairConflictPlanner
    public let localConflictFileManager: LocalConflictFileManaging
    public let now: @Sendable () -> Date

    public init(
        processClient: RcloneProcessRunning,
        driftService: DriftService = DriftService(),
        configPath: String? = nil,
        localFolderInspector: LocalFolderInspecting = FileManagerLocalFolderInspector(),
        excludeFileStore: RcloneExcludeFilePreparing? = nil,
        snapshotProvider: PairSnapshotProviding? = nil,
        baselineRepository: PairConflictStateStoring? = nil,
        planner: PairConflictPlanner = PairConflictPlanner(),
        localConflictFileManager: LocalConflictFileManaging = LocalConflictFileManager(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.processClient = processClient
        self.driftService = driftService
        self.configPath = configPath
        self.localFolderInspector = localFolderInspector
        self.excludeFileStore = excludeFileStore
        self.snapshotProvider = snapshotProvider ?? RcloneSnapshotProvider(
            processClient: processClient,
            configPath: configPath,
            excludeFileStore: excludeFileStore
        )
        self.baselineRepository = baselineRepository ?? NoopPairConflictStateStore()
        self.planner = planner
        self.localConflictFileManager = localConflictFileManager
        self.now = now
    }

    public func push(_ pair: SyncPair, executionMode: ExecutionMode = .manual) async -> OperationOutcome {
        let copy = AppCopy.current

        do {
            guard try localFolderInspector.containsUserVisibleContent(
                atPath: pair.localFolderDisplayPath,
                excludedPatterns: pair.syncExcludes
            ) else {
                let error = LocalFolderEmptyPushBlockedError(
                    pairName: pair.name,
                    localFolderPath: pair.localFolderDisplayPath,
                    remotePath: pair.remotePath
                )
                return OperationOutcome(severity: .warning, summary: copy.manualPushBlockedTitle, details: error.localizedDescription)
            }

            let localSnapshot = try await snapshotProvider.snapshot(for: pair, path: pair.localFolderDisplayPath, mode: .sync)
            let remoteSnapshot = try await snapshotProvider.snapshot(for: pair, path: pair.remotePath, mode: .sync)
            let baselinePreparation = try await prepareBaseline(pair: pair, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)

            if executionMode == .scheduled, !baselinePreparation.analysis.remoteOnlyChanged.isEmpty || !baselinePreparation.analysis.conflicts.isEmpty {
                return blockedPushOutcome(analysis: baselinePreparation.analysis, copy: copy)
            }

            switch pair.conflictPolicy {
            case .block:
                if !baselinePreparation.analysis.remoteOnlyChanged.isEmpty || !baselinePreparation.analysis.conflicts.isEmpty {
                    return blockedPushOutcome(analysis: baselinePreparation.analysis, copy: copy)
                }

                let syncLog = try await runCommand(syncArguments(for: pair))
                let baselineUpdated = try await refreshBaseline(for: pair)
                return OperationOutcome(
                    severity: .healthy,
                    summary: copy.manualSyncCompleted,
                    details: syncLog.detailedDescriptionIfUseful,
                    shouldUpdateLastSync: true,
                    updatedBaseline: baselineUpdated
                )

            case .keepBoth:
                if executionMode == .scheduled {
                    return blockedPushOutcome(analysis: baselinePreparation.analysis, copy: copy)
                }

                if baselinePreparation.analysis.remoteOnlyChanged.isEmpty && baselinePreparation.analysis.conflicts.isEmpty {
                    let syncLog = try await runCommand(syncArguments(for: pair))
                    let baselineUpdated = try await refreshBaseline(for: pair)
                    return OperationOutcome(
                        severity: .healthy,
                        summary: copy.manualSyncCompleted,
                        details: syncLog.detailedDescriptionIfUseful,
                        shouldUpdateLastSync: true,
                        updatedBaseline: baselineUpdated
                    )
                }

                let details = try await reconcileForPushKeepBoth(pair: pair, analysis: baselinePreparation.analysis)
                let syncLog = try await runCommand(syncArguments(for: pair))
                let baselineUpdated = try await refreshBaseline(for: pair)
                let joinedDetails = join(details, syncLog.detailedDescription)
                return OperationOutcome(
                    severity: .warning,
                    summary: copy.keepBothSummary(
                        conflictCount: baselinePreparation.analysis.remoteOnlyChanged.count + baselinePreparation.analysis.conflicts.count,
                        samplePath: baselinePreparation.analysis.sampleRemoteDriftPath
                    ),
                    details: joinedDetails,
                    shouldUpdateLastSync: true,
                    updatedBaseline: baselineUpdated
                )
            }
        } catch let error as LocalizedStateError {
            return OperationOutcome(
                severity: .warning,
                summary: copy.baselineMissingBlockedSummary,
                details: error.localizedDescription
            )
        } catch let error as CommandFailedError {
            return OperationOutcome(severity: .alarm, summary: error.summaryDescription, details: error.detailedDescription)
        } catch {
            return OperationOutcome(severity: .alarm, summary: error.localizedDescription, details: error.localizedDescription)
        }
    }

    public func check(_ pair: SyncPair) async -> OperationOutcome {
        let copy = AppCopy.current

        do {
            let checkLocalSnapshot = try await snapshotProvider.snapshot(for: pair, path: pair.localFolderDisplayPath, mode: .check)
            let checkRemoteSnapshot = try await snapshotProvider.snapshot(for: pair, path: pair.remotePath, mode: .check)
            let checkLog = try await runCommand(checkArguments(for: pair), allowWarningExitCode: true)

            if let baseline = try await baselineRepository.load(pairID: pair.id) {
                let filteredBaseline = filterBaseline(baseline, for: pair.allCheckExcludes)
                let analysis = planner.analyze(
                    baseline: filteredBaseline,
                    localSnapshot: checkLocalSnapshot,
                    remoteSnapshot: checkRemoteSnapshot
                )

                if !analysis.conflicts.isEmpty {
                    return OperationOutcome(
                        severity: .warning,
                        summary: copy.baselineAwareCheckSummary(copy.checkClassificationConflicts(count: analysis.conflicts.count)),
                        details: join(blockedDetails(prefix: copy.checkClassificationConflicts(count: analysis.conflicts.count), analysis: analysis), checkLog.detailedDescription),
                        differenceCount: analysis.conflicts.count + analysis.remoteOnlyChanged.count + analysis.localOnlyChanged.count
                    )
                }

                if !analysis.remoteOnlyChanged.isEmpty {
                    return OperationOutcome(
                        severity: .warning,
                        summary: copy.baselineAwareCheckSummary(copy.checkClassificationRemoteOnly(count: analysis.remoteOnlyChanged.count)),
                        details: join(blockedDetails(prefix: copy.checkClassificationRemoteOnly(count: analysis.remoteOnlyChanged.count), analysis: analysis), checkLog.detailedDescription),
                        differenceCount: analysis.remoteOnlyChanged.count
                    )
                }

                if !analysis.localOnlyChanged.isEmpty {
                    return OperationOutcome(
                        severity: .warning,
                        summary: copy.baselineAwareCheckSummary(copy.checkClassificationLocalOnly(count: analysis.localOnlyChanged.count)),
                        details: join(blockedDetails(prefix: copy.checkClassificationLocalOnly(count: analysis.localOnlyChanged.count), analysis: analysis), checkLog.detailedDescription),
                        differenceCount: analysis.localOnlyChanged.count
                    )
                }

                return OperationOutcome(
                    severity: .healthy,
                    summary: copy.baselineAwareCheckSummary(copy.checkClassificationClean),
                    details: checkLog.detailedDescriptionIfUseful,
                    differenceCount: 0
                )
            }

            let syncScopeLocal = try await snapshotProvider.snapshot(for: pair, path: pair.localFolderDisplayPath, mode: .sync)
            let syncScopeRemote = try await snapshotProvider.snapshot(for: pair, path: pair.remotePath, mode: .sync)
            switch planner.bootstrapDisposition(pairID: pair.id, localSnapshot: syncScopeLocal, remoteSnapshot: syncScopeRemote, now: now()) {
            case let .baselineCreated(state):
                try await baselineRepository.save(state)
                return OperationOutcome(
                    severity: .healthy,
                    summary: copy.baselineAwareCheckSummary(copy.checkClassificationClean),
                    details: checkLog.detailedDescriptionIfUseful,
                    differenceCount: 0,
                    updatedBaseline: true
                )
            case .baselineMissingWithDrift:
                return OperationOutcome(
                    severity: .warning,
                    summary: copy.baselineAwareCheckSummary(copy.checkClassificationBaselineMissing),
                    details: join(copy.baselineMissingBlockedSummary, checkLog.detailedDescription)
                )
            }
        } catch let error as LocalizedStateError {
            return OperationOutcome(
                severity: .warning,
                summary: copy.baselineMissingBlockedSummary,
                details: error.localizedDescription
            )
        } catch let error as CommandFailedError {
            return OperationOutcome(severity: .alarm, summary: error.summaryDescription, details: error.detailedDescription)
        } catch {
            return OperationOutcome(severity: .alarm, summary: error.localizedDescription, details: error.localizedDescription)
        }
    }

    public func pull(_ pair: SyncPair, executionMode: ExecutionMode = .manual) async -> OperationOutcome {
        let copy = AppCopy.current

        do {
            let localSnapshot = try await snapshotProvider.snapshot(for: pair, path: pair.localFolderDisplayPath, mode: .sync)
            let remoteSnapshot = try await snapshotProvider.snapshot(for: pair, path: pair.remotePath, mode: .sync)
            let baselinePreparation = try await prepareBaseline(pair: pair, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)

            switch pair.conflictPolicy {
            case .block:
                if !baselinePreparation.analysis.localOnlyChanged.isEmpty || !baselinePreparation.analysis.conflicts.isEmpty {
                    return blockedPullOutcome(analysis: baselinePreparation.analysis, copy: copy)
                }

                let pullLog = try await runCommand(pullArguments(for: pair))
                let baselineUpdated = try await refreshBaseline(for: pair)
                return OperationOutcome(
                    severity: .healthy,
                    summary: copy.manualPullCompleted,
                    details: pullLog.detailedDescriptionIfUseful,
                    updatedBaseline: baselineUpdated
                )

            case .keepBoth:
                if executionMode == .scheduled {
                    return blockedPullOutcome(analysis: baselinePreparation.analysis, copy: copy)
                }

                if baselinePreparation.analysis.localOnlyChanged.isEmpty && baselinePreparation.analysis.conflicts.isEmpty {
                    let pullLog = try await runCommand(pullArguments(for: pair))
                    let baselineUpdated = try await refreshBaseline(for: pair)
                    return OperationOutcome(
                        severity: .healthy,
                        summary: copy.manualPullCompleted,
                        details: pullLog.detailedDescriptionIfUseful,
                        updatedBaseline: baselineUpdated
                    )
                }

                let details = try await reconcileForPullKeepBoth(pair: pair, analysis: baselinePreparation.analysis)
                let pullLog = try await runCommand(pullArguments(for: pair))
                let baselineUpdated = try await refreshBaseline(for: pair)
                return OperationOutcome(
                    severity: .warning,
                    summary: copy.keepBothSummary(
                        conflictCount: baselinePreparation.analysis.localOnlyChanged.count + baselinePreparation.analysis.conflicts.count,
                        samplePath: baselinePreparation.analysis.sampleLocalDriftPath
                    ),
                    details: join(details, pullLog.detailedDescription),
                    updatedBaseline: baselineUpdated
                )
            }
        } catch let error as CommandFailedError {
            return OperationOutcome(severity: .alarm, summary: error.summaryDescription, details: error.detailedDescription)
        } catch {
            return OperationOutcome(severity: .alarm, summary: error.localizedDescription, details: error.localizedDescription)
        }
    }

    private func prepareBaseline(
        pair: SyncPair,
        localSnapshot: PairSnapshot,
        remoteSnapshot: PairSnapshot
    ) async throws -> BaselinePreparation {
        if let baseline = try await baselineRepository.load(pairID: pair.id) {
            let analysis = planner.analyze(baseline: baseline, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
            return BaselinePreparation(baseline: baseline, analysis: analysis)
        }

        switch planner.bootstrapDisposition(pairID: pair.id, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot, now: now()) {
        case let .baselineCreated(state):
            try await baselineRepository.save(state)
            let analysis = planner.analyze(baseline: state, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
            return BaselinePreparation(baseline: state, analysis: analysis)
        case .baselineMissingWithDrift:
            throw LocalizedStateError(message: AppCopy.current.baselineMissingBlockedSummary)
        }
    }

    private func refreshBaseline(for pair: SyncPair) async throws -> Bool {
        let localSnapshot = try await snapshotProvider.snapshot(for: pair, path: pair.localFolderDisplayPath, mode: .sync)
        let remoteSnapshot = try await snapshotProvider.snapshot(for: pair, path: pair.remotePath, mode: .sync)
        let state = PairConflictBaselineState(
            pairID: pair.id,
            localSnapshot: localSnapshot,
            remoteSnapshot: remoteSnapshot,
            updatedAt: now()
        )
        try await baselineRepository.save(state)
        return true
    }

    private func blockedPushOutcome(analysis: PairConflictPlanner.Analysis, copy: AppCopy) -> OperationOutcome {
        OperationOutcome(
            severity: .warning,
            summary: copy.remoteDriftBlockedSummary(count: analysis.changeCountForPushBlock, samplePath: analysis.sampleRemoteDriftPath),
            details: blockedDetails(prefix: copy.remoteDriftBlockedSummary(count: analysis.changeCountForPushBlock, samplePath: analysis.sampleRemoteDriftPath), analysis: analysis)
        )
    }

    private func blockedPullOutcome(analysis: PairConflictPlanner.Analysis, copy: AppCopy) -> OperationOutcome {
        OperationOutcome(
            severity: .warning,
            summary: copy.localDriftBlockedSummary(count: analysis.changeCountForPullBlock, samplePath: analysis.sampleLocalDriftPath),
            details: blockedDetails(prefix: copy.localDriftBlockedSummary(count: analysis.changeCountForPullBlock, samplePath: analysis.sampleLocalDriftPath), analysis: analysis)
        )
    }

    private func blockedDetails(prefix: String, analysis: PairConflictPlanner.Analysis) -> String {
        let changedPaths = (analysis.localOnlyChanged + analysis.remoteOnlyChanged + analysis.conflicts)
            .map(\.path)
            .prefix(12)
        let list = changedPaths.map { "- \($0)" }.joined(separator: "\n")
        if list.isEmpty {
            return prefix
        }
        return "\(prefix)\n\nAffected paths\n\(list)"
    }

    private func filterBaseline(_ baseline: PairConflictBaselineState, for excludes: [String]) -> PairConflictBaselineState {
        let matcher = RcloneExcludeMatcher(patterns: excludes)

        func filter(_ snapshot: PairSnapshot) -> PairSnapshot {
            PairSnapshot(entries: snapshot.entries.filter { !matcher.matches(relativePath: $0.path, isDirectory: false) })
        }

        return PairConflictBaselineState(
            pairID: baseline.pairID,
            localSnapshot: filter(baseline.localSnapshot),
            remoteSnapshot: filter(baseline.remoteSnapshot),
            updatedAt: baseline.updatedAt
        )
    }

    private func reconcileForPushKeepBoth(pair: SyncPair, analysis: PairConflictPlanner.Analysis) async throws -> String {
        var details: [String] = []
        let affectedPaths = analysis.remoteOnlyChanged + analysis.conflicts

        for result in affectedPaths {
            if result.local != nil, result.disposition != .remoteOnlyChanged {
                let conflictCopyURL = try localConflictFileManager.makeConflictCopy(for: pair, relativePath: result.path, at: now())
                let conflictRemotePath = SyncPair.composeRemotePath(
                    remoteName: pair.parsedRemoteName ?? "",
                    remoteSubpath: appendConflictComponent(result.path, fileName: conflictCopyURL.lastPathComponent)
                )
                let uploadLog = try await runCommand(
                    RcloneCommandBuilder.copyToArguments(
                        sourcePath: conflictCopyURL.path,
                        destinationPath: conflictRemotePath,
                        configPath: configPath
                    )
                )
                details.append(uploadLog.detailedDescription)
            }

            if result.remote != nil {
                let localCanonicalURL = localConflictFileManager.canonicalLocalURL(for: pair, relativePath: result.path)
                let pullLog = try await runCommand(
                    RcloneCommandBuilder.copyToArguments(
                        sourcePath: composeCanonicalRemotePath(pair: pair, relativePath: result.path),
                        destinationPath: localCanonicalURL.path,
                        configPath: configPath
                    )
                )
                details.append(pullLog.detailedDescription)
            } else {
                try localConflictFileManager.removeCanonicalLocalItem(for: pair, relativePath: result.path)
            }
        }

        return details.joined(separator: "\n\n")
    }

    private func reconcileForPullKeepBoth(pair: SyncPair, analysis: PairConflictPlanner.Analysis) async throws -> String {
        var details: [String] = []
        let affectedPaths = analysis.localOnlyChanged + analysis.conflicts

        for result in affectedPaths {
            if result.local != nil {
                let conflictCopyURL = try localConflictFileManager.makeConflictCopy(for: pair, relativePath: result.path, at: now())
                let conflictRemotePath = SyncPair.composeRemotePath(
                    remoteName: pair.parsedRemoteName ?? "",
                    remoteSubpath: appendConflictComponent(result.path, fileName: conflictCopyURL.lastPathComponent)
                )
                let uploadLog = try await runCommand(
                    RcloneCommandBuilder.copyToArguments(
                        sourcePath: conflictCopyURL.path,
                        destinationPath: conflictRemotePath,
                        configPath: configPath
                    )
                )
                details.append(uploadLog.detailedDescription)
            }

            if result.remote != nil {
                let localCanonicalURL = localConflictFileManager.canonicalLocalURL(for: pair, relativePath: result.path)
                let pullLog = try await runCommand(
                    RcloneCommandBuilder.copyToArguments(
                        sourcePath: composeCanonicalRemotePath(pair: pair, relativePath: result.path),
                        destinationPath: localCanonicalURL.path,
                        configPath: configPath
                    )
                )
                details.append(pullLog.detailedDescription)
            } else {
                try localConflictFileManager.removeCanonicalLocalItem(for: pair, relativePath: result.path)
            }
        }

        return details.joined(separator: "\n\n")
    }

    private func composeCanonicalRemotePath(pair: SyncPair, relativePath: String) -> String {
        let remoteName = pair.parsedRemoteName ?? ""
        let rootPath = pair.parsedRemoteSubpath
        let normalizedRelativePath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let remoteSubpath = rootPath.isEmpty ? normalizedRelativePath : "\(rootPath)/\(normalizedRelativePath)"
        return SyncPair.composeRemotePath(remoteName: remoteName, remoteSubpath: remoteSubpath)
    }

    private func appendConflictComponent(_ relativePath: String, fileName: String) -> String {
        let parent = URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
        let normalizedParent = parent == "/" ? "" : parent.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalizedParent.isEmpty ? fileName : "\(normalizedParent)/\(fileName)"
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

    private func runCommand(_ arguments: [String], allowWarningExitCode: Bool = false) async throws -> RcloneCommandLog {
        let result = try await processClient.run(arguments)
        let log = RcloneCommandLog(
            command: arguments,
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode
        )

        if result.exitCode == 0 || (allowWarningExitCode && driftService.dispositionForCheck(stdout: result.stdout, stderr: result.stderr, exitCode: result.exitCode) == .warning) {
            return log
        }

        throw CommandFailedError(command: arguments, exitCode: result.exitCode, stdout: result.stdout, stderr: result.stderr)
    }

    private func join(_ lhs: String?, _ rhs: String?) -> String? {
        switch (lhs?.trimmingCharacters(in: .whitespacesAndNewlines), rhs?.trimmingCharacters(in: .whitespacesAndNewlines)) {
        case let (.some(lhs), .some(rhs)) where !lhs.isEmpty && !rhs.isEmpty:
            return "\(lhs)\n\n\(rhs)"
        case let (.some(lhs), _) where !lhs.isEmpty:
            return lhs
        case let (_, .some(rhs)) where !rhs.isEmpty:
            return rhs
        default:
            return nil
        }
    }
}

private struct LocalizedStateError: Error, LocalizedError, Sendable {
    let message: String

    var errorDescription: String? {
        message
    }
}

private extension SyncService.RcloneCommandLog {
    var detailedDescriptionIfUseful: String? {
        let normalizedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedStdout.isEmpty && normalizedStderr.isEmpty ? nil : detailedDescription
    }
}
