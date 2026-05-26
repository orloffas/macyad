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
        public let issueSet: ActivityIssueSet?
        public let differenceCount: Int?
        public let shouldUpdateLastSync: Bool
        public let updatedBaseline: Bool

        public init(
            severity: Severity,
            summary: String,
            details: String?,
            issueSet: ActivityIssueSet? = nil,
            differenceCount: Int? = nil,
            shouldUpdateLastSync: Bool = false,
            updatedBaseline: Bool = false
        ) {
            self.severity = severity
            self.summary = summary
            self.details = details
            self.issueSet = issueSet
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

    private enum BaselinePreparationResult {
        case ready(BaselinePreparation)
        case missingWithDrift(PairConflictPlanner.Analysis)
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
            switch baselinePreparation {
            case let .missingWithDrift(analysis):
                return blockedPushOutcome(analysis: analysis, copy: copy, baselineMissing: true)
            case let .ready(preparation):
                if executionMode == .scheduled, !preparation.analysis.remoteOnlyChanged.isEmpty || !preparation.analysis.conflicts.isEmpty {
                    return blockedPushOutcome(analysis: preparation.analysis, copy: copy, baselineMissing: false)
                }

                if !preparation.analysis.remoteOnlyChanged.isEmpty || !preparation.analysis.conflicts.isEmpty {
                    return blockedPushOutcome(analysis: preparation.analysis, copy: copy, baselineMissing: false)
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
            }
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
                    let issueSet = makeIssueSet(from: analysis, baselineMissing: false)
                    return OperationOutcome(
                        severity: .warning,
                        summary: copy.baselineAwareCheckSummary(copy.checkClassificationConflicts(count: analysis.conflicts.count)),
                        details: join(structuredIssueDetails(prefix: copy.checkClassificationConflicts(count: analysis.conflicts.count), issueSet: issueSet), checkLog.detailedDescription),
                        issueSet: issueSet,
                        differenceCount: analysis.conflicts.count + analysis.remoteOnlyChanged.count + analysis.localOnlyChanged.count
                    )
                }

                if !analysis.remoteOnlyChanged.isEmpty {
                    let issueSet = makeIssueSet(from: analysis, baselineMissing: false)
                    return OperationOutcome(
                        severity: .warning,
                        summary: copy.baselineAwareCheckSummary(copy.checkClassificationRemoteOnly(count: analysis.remoteOnlyChanged.count)),
                        details: join(structuredIssueDetails(prefix: copy.checkClassificationRemoteOnly(count: analysis.remoteOnlyChanged.count), issueSet: issueSet), checkLog.detailedDescription),
                        issueSet: issueSet,
                        differenceCount: analysis.remoteOnlyChanged.count
                    )
                }

                if !analysis.localOnlyChanged.isEmpty {
                    let issueSet = makeIssueSet(from: analysis, baselineMissing: false)
                    return OperationOutcome(
                        severity: .warning,
                        summary: copy.baselineAwareCheckSummary(copy.checkClassificationLocalOnly(count: analysis.localOnlyChanged.count)),
                        details: join(structuredIssueDetails(prefix: copy.checkClassificationLocalOnly(count: analysis.localOnlyChanged.count), issueSet: issueSet), checkLog.detailedDescription),
                        issueSet: issueSet,
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
            case let .baselineMissingWithDrift(analysis):
                let issueSet = makeIssueSet(from: analysis, baselineMissing: true)
                return OperationOutcome(
                    severity: .warning,
                    summary: copy.baselineAwareCheckSummary(copy.checkClassificationBaselineMissing),
                    details: join(structuredIssueDetails(prefix: copy.baselineMissingBlockedSummary, issueSet: issueSet), checkLog.detailedDescription),
                    issueSet: issueSet
                )
            }
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
            switch baselinePreparation {
            case let .missingWithDrift(analysis):
                return blockedPullOutcome(analysis: analysis, copy: copy, baselineMissing: true)
            case let .ready(preparation):
                if executionMode == .scheduled, !preparation.analysis.localOnlyChanged.isEmpty || !preparation.analysis.conflicts.isEmpty {
                    return blockedPullOutcome(analysis: preparation.analysis, copy: copy, baselineMissing: false)
                }

                if !preparation.analysis.localOnlyChanged.isEmpty || !preparation.analysis.conflicts.isEmpty {
                    return blockedPullOutcome(analysis: preparation.analysis, copy: copy, baselineMissing: false)
                }

                let pullLog = try await runCommand(pullArguments(for: pair))
                let baselineUpdated = try await refreshBaseline(for: pair)
                return OperationOutcome(
                    severity: .healthy,
                    summary: copy.manualPullCompleted,
                    details: pullLog.detailedDescriptionIfUseful,
                    updatedBaseline: baselineUpdated
                )
            }
        } catch let error as CommandFailedError {
            return OperationOutcome(severity: .alarm, summary: error.summaryDescription, details: error.detailedDescription)
        } catch {
            return OperationOutcome(severity: .alarm, summary: error.localizedDescription, details: error.localizedDescription)
        }
    }

    public func applyResolutions(_ issueSet: ActivityIssueSet, for pair: SyncPair) async -> OperationOutcome {
        let copy = AppCopy.current
        var logs: [String] = []
        let issuesToApply = issueSet.issues.filter { $0.selectedDecision != .later }
        let remainingIssues = issueSet.issues.filter { $0.selectedDecision == .later }

        do {
            for issue in issuesToApply {
                logs.append(contentsOf: try await applyResolution(issue, for: pair))
            }

            if remainingIssues.isEmpty {
                let baselineUpdated = try await refreshBaseline(for: pair)
                return OperationOutcome(
                    severity: .healthy,
                    summary: copy.issueResolutionCompleted(count: issuesToApply.count),
                    details: join(copy.issueResolutionDetails(appliedCount: issuesToApply.count, remainingCount: 0), joinLogs(logs)),
                    updatedBaseline: baselineUpdated
                )
            }

            let remainingIssueSet = ActivityIssueSet(issues: remainingIssues)
            return OperationOutcome(
                severity: .warning,
                summary: copy.issueResolutionRemaining(count: remainingIssues.count),
                details: join(copy.issueResolutionDetails(appliedCount: issuesToApply.count, remainingCount: remainingIssues.count), joinLogs(logs)),
                issueSet: remainingIssueSet
            )
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
    ) async throws -> BaselinePreparationResult {
        if let baseline = try await baselineRepository.load(pairID: pair.id) {
            let analysis = planner.analyze(baseline: baseline, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
            return .ready(BaselinePreparation(baseline: baseline, analysis: analysis))
        }

        switch planner.bootstrapDisposition(pairID: pair.id, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot, now: now()) {
        case let .baselineCreated(state):
            try await baselineRepository.save(state)
            let analysis = planner.analyze(baseline: state, localSnapshot: localSnapshot, remoteSnapshot: remoteSnapshot)
            return .ready(BaselinePreparation(baseline: state, analysis: analysis))
        case let .baselineMissingWithDrift(analysis):
            return .missingWithDrift(analysis)
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

    private func blockedPushOutcome(analysis: PairConflictPlanner.Analysis, copy: AppCopy, baselineMissing: Bool) -> OperationOutcome {
        let issueSet = makeIssueSet(from: analysis, baselineMissing: baselineMissing)
        let summary = baselineMissing
            ? copy.baselineMissingBlockedSummary
            : copy.remoteDriftBlockedSummary(count: analysis.changeCountForPushBlock, samplePath: analysis.sampleRemoteDriftPath)
        return OperationOutcome(
            severity: .warning,
            summary: summary,
            details: structuredIssueDetails(prefix: summary, issueSet: issueSet),
            issueSet: issueSet
        )
    }

    private func blockedPullOutcome(analysis: PairConflictPlanner.Analysis, copy: AppCopy, baselineMissing: Bool) -> OperationOutcome {
        let issueSet = makeIssueSet(from: analysis, baselineMissing: baselineMissing)
        let summary = baselineMissing
            ? copy.baselineMissingBlockedSummary
            : copy.localDriftBlockedSummary(count: analysis.changeCountForPullBlock, samplePath: analysis.sampleLocalDriftPath)
        return OperationOutcome(
            severity: .warning,
            summary: summary,
            details: structuredIssueDetails(prefix: summary, issueSet: issueSet),
            issueSet: issueSet
        )
    }

    private func makeIssueSet(from analysis: PairConflictPlanner.Analysis, baselineMissing: Bool) -> ActivityIssueSet {
        ActivityIssueSet(issues: analysis.pathResults.compactMap { result in
            guard result.disposition != .unchanged, result.disposition != .bothChangedIdentical else {
                return nil
            }

            let problemKind: ActivityFileProblemKind = switch result.disposition {
            case .localOnlyChanged:
                .localOnlyChanged
            case .remoteOnlyChanged:
                .remoteOnlyChanged
            case .conflict:
                .conflict
            case .deleteVsModifyConflict:
                .deleteVsModifyConflict
            case .unchanged, .bothChangedIdentical:
                .conflict
            }

            var differences = result.observedDifferences
            if baselineMissing, !differences.contains(.baselineMissing) {
                differences.append(.baselineMissing)
            }

            let baselineSnapshot = result.baselineRemote ?? result.baselineLocal
            return ActivityFileIssue(
                relativePath: result.path,
                problemKind: problemKind,
                differences: Array(Set(differences)).sorted { $0.rawValue < $1.rawValue },
                localSnapshot: result.local,
                remoteSnapshot: result.remote,
                baselineSnapshot: baselineSnapshot,
                selectedDecision: .later
            )
        })
    }

    private func structuredIssueDetails(prefix: String, issueSet: ActivityIssueSet) -> String {
        guard !issueSet.issues.isEmpty else {
            return prefix
        }

        let issueBlocks = issueSet.issues.map { issue in
            """
            Path: \(issue.relativePath)
            Problem: \(describe(issue.problemKind))
            Differences: \(describe(issue.differences))
            Local: \(describe(issue.localSnapshot))
            Remote: \(describe(issue.remoteSnapshot))
            Baseline: \(describe(issue.baselineSnapshot))
            """
        }.joined(separator: "\n\n")

        return "\(prefix)\n\n\(issueBlocks)"
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

    private func applyResolution(_ issue: ActivityFileIssue, for pair: SyncPair) async throws -> [String] {
        switch issue.selectedDecision {
        case .later:
            return []
        case .keepLocal:
            return try await applyKeepLocal(issue, for: pair)
        case .keepRemote:
            return try await applyKeepRemote(issue, for: pair)
        case .keepBoth:
            return try await applyKeepBoth(issue, for: pair)
        }
    }

    private func composeCanonicalRemotePath(pair: SyncPair, relativePath: String) -> String {
        let remoteName = pair.parsedRemoteName ?? ""
        let rootPath = pair.parsedRemoteSubpath
        let normalizedRelativePath = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let remoteSubpath = rootPath.isEmpty ? normalizedRelativePath : "\(rootPath)/\(normalizedRelativePath)"
        return SyncPair.composeRemotePath(remoteName: remoteName, remoteSubpath: remoteSubpath)
    }

    private func applyKeepLocal(_ issue: ActivityFileIssue, for pair: SyncPair) async throws -> [String] {
        if issue.localSnapshot != nil {
            let log = try await runCommand(
                RcloneCommandBuilder.copyToArguments(
                    sourcePath: localConflictFileManager.canonicalLocalURL(for: pair, relativePath: issue.relativePath).path,
                    destinationPath: composeCanonicalRemotePath(pair: pair, relativePath: issue.relativePath),
                    configPath: configPath
                )
            )
            return [log.detailedDescription]
        }

        if issue.remoteSnapshot != nil {
            let log = try await runCommand(
                RcloneCommandBuilder.deleteFileArguments(
                    path: composeCanonicalRemotePath(pair: pair, relativePath: issue.relativePath),
                    configPath: configPath
                )
            )
            return [log.detailedDescription]
        }

        return []
    }

    private func applyKeepRemote(_ issue: ActivityFileIssue, for pair: SyncPair) async throws -> [String] {
        if issue.remoteSnapshot != nil {
            let log = try await runCommand(
                RcloneCommandBuilder.copyToArguments(
                    sourcePath: composeCanonicalRemotePath(pair: pair, relativePath: issue.relativePath),
                    destinationPath: localConflictFileManager.canonicalLocalURL(for: pair, relativePath: issue.relativePath).path,
                    configPath: configPath
                )
            )
            return [log.detailedDescription]
        }

        if issue.localSnapshot != nil {
            try localConflictFileManager.removeCanonicalLocalItem(for: pair, relativePath: issue.relativePath)
            return ["Removed local item \(issue.relativePath)"]
        }

        return []
    }

    private func applyKeepBoth(_ issue: ActivityFileIssue, for pair: SyncPair) async throws -> [String] {
        let resolutionDate = now()
        let localConflictRelativePath = renamedConflictRelativePath(issue.relativePath, source: "local", at: resolutionDate)
        let remoteConflictRelativePath = renamedConflictRelativePath(issue.relativePath, source: "remote", at: resolutionDate)
        var logs: [String] = []

        if issue.localSnapshot != nil {
            let localConflictURL = try localConflictFileManager.moveCanonicalLocalItem(
                for: pair,
                relativePath: issue.relativePath,
                to: localConflictRelativePath
            )
            logs.append("Moved local item to \(localConflictRelativePath)")
            let uploadLog = try await runCommand(
                RcloneCommandBuilder.copyToArguments(
                    sourcePath: localConflictURL.path,
                    destinationPath: composeCanonicalRemotePath(pair: pair, relativePath: localConflictRelativePath),
                    configPath: configPath
                )
            )
            logs.append(uploadLog.detailedDescription)
        }

        if issue.remoteSnapshot != nil {
            let localRemoteConflictURL = localConflictFileManager.canonicalLocalURL(for: pair, relativePath: remoteConflictRelativePath)
            let downloadLog = try await runCommand(
                RcloneCommandBuilder.copyToArguments(
                    sourcePath: composeCanonicalRemotePath(pair: pair, relativePath: issue.relativePath),
                    destinationPath: localRemoteConflictURL.path,
                    configPath: configPath
                )
            )
            logs.append(downloadLog.detailedDescription)

            let remoteCopyLog = try await runCommand(
                RcloneCommandBuilder.copyToArguments(
                    sourcePath: composeCanonicalRemotePath(pair: pair, relativePath: issue.relativePath),
                    destinationPath: composeCanonicalRemotePath(pair: pair, relativePath: remoteConflictRelativePath),
                    configPath: configPath
                )
            )
            logs.append(remoteCopyLog.detailedDescription)

            let remoteDeleteLog = try await runCommand(
                RcloneCommandBuilder.deleteFileArguments(
                    path: composeCanonicalRemotePath(pair: pair, relativePath: issue.relativePath),
                    configPath: configPath
                )
            )
            logs.append(remoteDeleteLog.detailedDescription)
        }

        return logs
    }

    private func renamedConflictRelativePath(_ relativePath: String, source: String, at date: Date) -> String {
        let url = URL(fileURLWithPath: relativePath)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let stamp = formatter.string(from: date)
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let renamed = ext.isEmpty
            ? "\(baseName) (MacYaD conflict \(source) \(stamp))"
            : "\(baseName) (MacYaD conflict \(source) \(stamp)).\(ext)"
        let parent = url.deletingLastPathComponent().path
        if parent == "/" || parent.isEmpty {
            return renamed
        }
        return "\(parent.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/\(renamed)"
    }

    private func describe(_ issueKind: ActivityFileProblemKind) -> String {
        switch issueKind {
        case .remoteOnlyChanged:
            return "remote-only changed"
        case .localOnlyChanged:
            return "local-only changed"
        case .conflict:
            return "conflict"
        case .deleteVsModifyConflict:
            return "delete-vs-modify conflict"
        }
    }

    private func describe(_ differences: [ActivityFileDifference]) -> String {
        differences.map(\.rawValue).joined(separator: ", ")
    }

    private func describe(_ snapshot: PairSnapshotEntry?) -> String {
        guard let snapshot else {
            return "<missing>"
        }
        let modTime = snapshot.modTime?.ISO8601Format() ?? "<nil>"
        let hash = snapshot.md5 ?? "<nil>"
        return "size=\(snapshot.size), mtime=\(modTime), md5=\(hash)"
    }

    private func joinLogs(_ logs: [String]) -> String? {
        let joined = logs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return joined.isEmpty ? nil : joined
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

private extension SyncService.RcloneCommandLog {
    var detailedDescriptionIfUseful: String? {
        let normalizedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedStdout.isEmpty && normalizedStderr.isEmpty ? nil : detailedDescription
    }
}
