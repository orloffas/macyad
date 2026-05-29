import XCTest
@testable import MacyadCore

final class SyncServiceTests: XCTestCase {
    func testInitialPushStillBlocksWhenLocalIsEmptyAndRemoteHasFiles() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let processClient = StubProcessClient(result: ("", "", 0))
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false),
            snapshotProvider: StubSnapshotProvider(
                snapshotsByPath: [
                    pair.localFolderDisplayPath: PairSnapshot(entries: []),
                    pair.remotePath: snapshot(("draft.txt", "remote")),
                ]
            ),
            baselineRepository: InMemoryBaselineStore()
        )

        let outcome = await service.push(pair)

        XCTAssertEqual(outcome.severity, .warning)
        XCTAssertEqual(outcome.summary, AppCopy.current.baselineMissingBlockedSummary)
        XCTAssertEqual(outcome.issueSet?.issues.map(\.relativePath), ["draft.txt"])
        XCTAssertEqual(outcome.issueSet?.issues.first?.problemKind, .remoteOnlyChanged)
        XCTAssertTrue(outcome.details?.contains("Problem: remote-only changed") == true)

        let recordedArguments = await processClient.recordedArguments()
        XCTAssertTrue(recordedArguments.isEmpty)
    }

    func testPushRunsRcloneWhenLocalFolderHasUserVisibleContent() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let processClient = StubProcessClient(result: ("", "", 0))
        let excludeFileStore = StubExcludeFileStore()
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            excludeFileStore: excludeFileStore,
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
            baselineRepository: InMemoryBaselineStore()
        )

        let outcome = await service.push(pair)

        XCTAssertEqual(outcome.severity, .healthy)
        XCTAssertTrue(outcome.shouldUpdateLastSync)
        XCTAssertTrue(outcome.updatedBaseline)

        let recordedArguments = await processClient.recordedArguments()
        XCTAssertEqual(
            recordedArguments,
            [[
                "--config",
                "/tmp/macyad-rclone.conf",
                "sync",
                "/Users/test/Work Docs",
                "yd:/Work Docs",
                "--exclude-from",
                "/tmp/sync-excludes.txt",
            ]]
        )
        XCTAssertEqual(excludeFileStore.preparedModes(), [.sync])
    }

    func testCheckReturnsWarningWhenRemoteChangesDetected() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let baseline = PairConflictBaselineState(
            pairID: pair.id,
            localSnapshot: PairSnapshot(entries: []),
            remoteSnapshot: PairSnapshot(entries: []),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let processClient = StubProcessClient(
            result: ("", "NOTICE: Yandex Docs: 1 differences found\nNOTICE: Yandex Docs: 1 errors while checking", 1)
        )
        let excludeFileStore = StubExcludeFileStore()
        let snapshots = [
            pair.localFolderDisplayPath: PairSnapshot(entries: []),
            pair.remotePath: PairSnapshot(entries: [entry(path: "draft.txt", md5: "remote-v2")]),
        ]
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            excludeFileStore: excludeFileStore,
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: snapshots),
            baselineRepository: InMemoryBaselineStore(initialStates: [pair.id: baseline])
        )

        let outcome = await service.check(pair)

        XCTAssertEqual(outcome.severity, .warning)
        XCTAssertTrue(outcome.summary.contains("remote"))
        XCTAssertTrue(outcome.details?.contains("1 differences found") == true)
        XCTAssertEqual(outcome.differenceCount, 1)
        XCTAssertEqual(outcome.issueSet?.issues.map(\.relativePath), ["draft.txt"])
        XCTAssertEqual(outcome.issueSet?.issues.first?.problemKind, .remoteOnlyChanged)
        XCTAssertEqual(excludeFileStore.preparedModes(), [.check])
    }

    func testCheckReturnsHealthyWhenRcloneReportsZeroDifferences() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let cleanSnapshot = PairSnapshot(entries: [entry(path: "draft.txt", md5: "same")])
        let baseline = PairConflictBaselineState(
            pairID: pair.id,
            localSnapshot: cleanSnapshot,
            remoteSnapshot: cleanSnapshot,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let processClient = StubProcessClient(
            result: ("", "NOTICE: Yandex Docs: 0 differences found\nNOTICE: Yandex Docs: 5 matching files", 0)
        )
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            snapshotProvider: StubSnapshotProvider(
                snapshotsByPath: [
                    pair.localFolderDisplayPath: cleanSnapshot,
                    pair.remotePath: cleanSnapshot,
                ]
            ),
            baselineRepository: InMemoryBaselineStore(initialStates: [pair.id: baseline])
        )

        let outcome = await service.check(pair)

        XCTAssertEqual(outcome.severity, .healthy)
        XCTAssertEqual(outcome.differenceCount, 0)
        XCTAssertNil(outcome.issueSet)
    }

    func testCheckReturnsAlarmForNonDriftCommandFailures() async {
        let pair = makePair()
        let cleanSnapshot = PairSnapshot(entries: [])
        let baseline = PairConflictBaselineState(
            pairID: pair.id,
            localSnapshot: cleanSnapshot,
            remoteSnapshot: cleanSnapshot,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let processClient = StubProcessClient(result: ("", "permission denied", 9))
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            snapshotProvider: StubSnapshotProvider(
                snapshotsByPath: [
                    pair.localFolderDisplayPath: cleanSnapshot,
                    pair.remotePath: cleanSnapshot,
                ]
            ),
            baselineRepository: InMemoryBaselineStore(initialStates: [pair.id: baseline])
        )

        let outcome = await service.check(pair)

        XCTAssertEqual(outcome.severity, .alarm)
        XCTAssertTrue(outcome.summary.contains("code 9"))
        XCTAssertTrue(outcome.details?.contains("permission denied") == true)
    }

    func testPullUsesCopyCommand() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let processClient = StubProcessClient(result: ("", "", 0))
        let excludeFileStore = StubExcludeFileStore()
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            excludeFileStore: excludeFileStore,
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
            baselineRepository: InMemoryBaselineStore()
        )

        let outcome = await service.pull(pair)

        XCTAssertEqual(outcome.severity, .healthy)
        let recordedArguments = await processClient.recordedArguments()
        XCTAssertEqual(
            recordedArguments,
            [[
                "--config",
                "/tmp/macyad-rclone.conf",
                "copy",
                "yd:/Work Docs",
                "/Users/test/Work Docs",
                "--exclude-from",
                "/tmp/sync-excludes.txt",
            ]]
        )
        XCTAssertEqual(excludeFileStore.preparedModes(), [.sync])
    }

    func testInitialPullRunsWhenRemoteOnlyFilesCanBeAddedLocally() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let processClient = StubProcessClient(result: ("", "", 0))
        let excludeFileStore = StubExcludeFileStore()
        let baselineStore = InMemoryBaselineStore()
        let snapshotProvider = RecordingSnapshotProvider(
            snapshotsByPath: [
                pair.localFolderDisplayPath: [
                    snapshot(("seed.txt", "remote")),
                ]
            ]
        )
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false),
            excludeFileStore: excludeFileStore,
            snapshotProvider: snapshotProvider,
            baselineRepository: baselineStore
        )

        let outcome = await service.pull(pair)
        let recordedArguments = await processClient.recordedArguments()
        let savedBaseline = try await baselineStore.load(pairID: pair.id)
        let requestedPaths = await snapshotProvider.requestedPaths()

        XCTAssertEqual(outcome.severity, .healthy)
        XCTAssertTrue(outcome.updatedBaseline)
        XCTAssertEqual(
            recordedArguments,
            [[
                "--config",
                "/tmp/macyad-rclone.conf",
                "copy",
                "yd:/Work Docs",
                "/Users/test/Work Docs",
                "--exclude-from",
                "/tmp/sync-excludes.txt",
            ]]
        )
        XCTAssertEqual(requestedPaths, [pair.localFolderDisplayPath])
        XCTAssertEqual(savedBaseline?.localSnapshot.entries.map(\.path), ["seed.txt"])
        XCTAssertEqual(savedBaseline?.remoteSnapshot.entries.map(\.path), ["seed.txt"])
        XCTAssertEqual(excludeFileStore.preparedModes(), [.sync])
    }

    func testInitialPushRunsWhenLocalOnlyFilesCanBeAddedToEmptyRemote() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let processClient = StubProcessClient(result: ("", "", 0))
        let excludeFileStore = StubExcludeFileStore()
        let baselineStore = InMemoryBaselineStore()
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false),
            excludeFileStore: excludeFileStore,
            snapshotProvider: StubSnapshotProvider(
                snapshotsByPath: [
                    pair.localFolderDisplayPath: snapshot(("seed.txt", "local")),
                    pair.remotePath: PairSnapshot(entries: []),
                ]
            ),
            baselineRepository: baselineStore
        )

        let outcome = await service.push(pair)
        let recordedArguments = await processClient.recordedArguments()
        let savedBaseline = try await baselineStore.load(pairID: pair.id)

        XCTAssertEqual(outcome.severity, .healthy)
        XCTAssertTrue(outcome.shouldUpdateLastSync)
        XCTAssertTrue(outcome.updatedBaseline)
        XCTAssertEqual(
            recordedArguments,
            [[
                "--config",
                "/tmp/macyad-rclone.conf",
                "sync",
                "/Users/test/Work Docs",
                "yd:/Work Docs",
                "--exclude-from",
                "/tmp/sync-excludes.txt",
            ]]
        )
        XCTAssertEqual(savedBaseline?.localSnapshot.entries.map(\.path), ["seed.txt"])
        XCTAssertEqual(excludeFileStore.preparedModes(), [.sync])
    }

    func testPullSkipsNewScanWhenMatchingRcloneCopyIsAlreadyRunning() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let processClient = StubProcessClient(result: ("", "", 0))
        let snapshotProvider = RecordingSnapshotProvider(snapshotsByPath: [:])
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: snapshotProvider,
            baselineRepository: InMemoryBaselineStore(),
            operationInspector: StubRcloneOperationInspector(
                activeOperation: ActiveRcloneCopyOperation(
                    pid: 4_863,
                    commandLine: "rclone copy yd:/Work Docs /Users/test/Work Docs --exclude-from /tmp/sync-excludes.txt"
                )
            )
        )

        let outcome = await service.pull(pair)
        let recordedArguments = await processClient.recordedArguments()
        let requestedPaths = await snapshotProvider.requestedPaths()

        XCTAssertEqual(outcome.severity, .warning)
        XCTAssertEqual(outcome.summary, AppCopy.current.manualPullAlreadyRunningTitle)
        XCTAssertTrue(outcome.details?.contains("PID 4863") == true)
        XCTAssertTrue(outcome.details?.contains("rclone copy") == true)
        XCTAssertTrue(recordedArguments.isEmpty)
        XCTAssertTrue(requestedPaths.isEmpty)
    }

    func testPushBlockedByRemoteDriftReturnsStructuredIssueSet() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let baseline = PairConflictBaselineState(
            pairID: pair.id,
            localSnapshot: snapshot(("draft.txt", "same")),
            remoteSnapshot: snapshot(("draft.txt", "same")),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let snapshots = [
            pair.localFolderDisplayPath: snapshot(("draft.txt", "same")),
            pair.remotePath: PairSnapshot(entries: [
                PairSnapshotEntry(path: "draft.txt", size: 18, modTime: Date(timeIntervalSince1970: 2_000), md5: "remote-v2")
            ]),
        ]
        let service = SyncService(
            processClient: StubProcessClient(result: ("", "", 0)),
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: snapshots),
            baselineRepository: InMemoryBaselineStore(initialStates: [pair.id: baseline])
        )

        let outcome = await service.push(pair)

        XCTAssertEqual(outcome.severity, Severity.warning)
        XCTAssertEqual(outcome.issueSet?.issues.map { $0.relativePath }, ["draft.txt"])
        XCTAssertEqual(outcome.issueSet?.issues.first?.problemKind, .remoteOnlyChanged)
        XCTAssertTrue(outcome.details?.contains("draft.txt") == true)
    }

    func testPushWithMissingBaselineStillReturnsPerFileIssues() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let local = PairSnapshot(entries: [
            PairSnapshotEntry(path: "test.txt", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: "local")
        ])
        let remote = PairSnapshot(entries: [
            PairSnapshotEntry(path: "test.txt", size: 18, modTime: Date(timeIntervalSince1970: 2_000), md5: "remote")
        ])
        let service = SyncService(
            processClient: StubProcessClient(result: ("", "", 0)),
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(
                snapshotsByPath: [
                    pair.localFolderDisplayPath: local,
                    pair.remotePath: remote,
                ]
            ),
            baselineRepository: InMemoryBaselineStore()
        )

        let outcome = await service.push(pair)

        XCTAssertEqual(outcome.severity, Severity.warning)
        XCTAssertEqual(outcome.issueSet?.issues.first?.relativePath, "test.txt")
        XCTAssertTrue(outcome.issueSet?.issues.first?.differences.contains(.baselineMissing) == true)
    }

    func testInitialPushWithMixedOneSidedDriftStillBlocksWhenBaselineMissing() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let service = SyncService(
            processClient: StubProcessClient(result: ("", "", 0)),
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(
                snapshotsByPath: [
                    pair.localFolderDisplayPath: snapshot(("local-only.txt", "local")),
                    pair.remotePath: snapshot(("remote-only.txt", "remote")),
                ]
            ),
            baselineRepository: InMemoryBaselineStore()
        )

        let outcome = await service.push(pair)

        XCTAssertEqual(outcome.severity, .warning)
        XCTAssertEqual(outcome.issueSet?.issues.map(\.relativePath), ["local-only.txt", "remote-only.txt"])
        XCTAssertTrue(outcome.issueSet?.issues.allSatisfy { $0.differences.contains(.baselineMissing) } == true)
    }

    func testApplyResolutionsUpdatesIssueSetForUnresolvedRowsOnly() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let processClient = StubProcessClient(result: ("", "", 0))
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
            baselineRepository: InMemoryBaselineStore()
        )
        let issueSet = ActivityIssueSet(
            issues: [
                ActivityFileIssue(
                    relativePath: "keep-local.txt",
                    problemKind: .remoteOnlyChanged,
                    differences: [.sizeDiffers],
                    localSnapshot: PairSnapshotEntry(path: "keep-local.txt", size: 10, modTime: Date(timeIntervalSince1970: 1_000), md5: "local"),
                    remoteSnapshot: PairSnapshotEntry(path: "keep-local.txt", size: 20, modTime: Date(timeIntervalSince1970: 2_000), md5: "remote"),
                    baselineSnapshot: PairSnapshotEntry(path: "keep-local.txt", size: 10, modTime: Date(timeIntervalSince1970: 900), md5: "base"),
                    selectedDecision: .keepLocal
                ),
                ActivityFileIssue(
                    relativePath: "later.txt",
                    problemKind: .conflict,
                    differences: [.hashDiffers],
                    localSnapshot: PairSnapshotEntry(path: "later.txt", size: 10, modTime: Date(timeIntervalSince1970: 1_000), md5: "local"),
                    remoteSnapshot: PairSnapshotEntry(path: "later.txt", size: 20, modTime: Date(timeIntervalSince1970: 2_000), md5: "remote"),
                    baselineSnapshot: PairSnapshotEntry(path: "later.txt", size: 9, modTime: Date(timeIntervalSince1970: 900), md5: "base"),
                    selectedDecision: .later
                )
            ]
        )

        let outcome = await service.applyResolutions(issueSet, for: pair)

        XCTAssertEqual(outcome.severity, Severity.warning)
        XCTAssertEqual(outcome.issueSet?.issues.map { $0.relativePath }, ["later.txt"])
    }

    func testCommandFailureDescriptionUsesSelectedLanguage() {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let error = SyncService.CommandFailedError(
            command: ["sync", "/tmp/source", "yd:/target"],
            exitCode: 12,
            stdout: "NOTICE: remote object would be replaced",
            stderr: "permission denied"
        )

        XCTAssertEqual(
            error.localizedDescription,
            "rclone sync /tmp/source yd:/target exited with code 12: permission denied"
        )
        XCTAssertEqual(
            error.summaryDescription,
            "rclone exited with code 12: permission denied"
        )
        XCTAssertTrue(error.detailedDescription.contains("NOTICE: remote object would be replaced"))
        XCTAssertTrue(error.detailedDescription.contains("permission denied"))
    }

    private func makePair() -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Work Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Work Docs",
            remotePath: "yd:/Work Docs",
            accountID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            conflictPolicy: .block,
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy
        )
    }

    private func cleanSnapshots(for pairs: [SyncPair]) -> [String: PairSnapshot] {
        var snapshots: [String: PairSnapshot] = [:]
        let empty = PairSnapshot(entries: [])
        for pair in pairs {
            snapshots[pair.localFolderDisplayPath] = empty
            snapshots[pair.remotePath] = empty
        }
        return snapshots
    }

    private func snapshot(_ files: (String, String)...) -> PairSnapshot {
        PairSnapshot(entries: files.map { path, hash in
            PairSnapshotEntry(path: path, size: Int64(hash.count), modTime: Date(timeIntervalSince1970: 1_000), md5: hash)
        })
    }

    private func entry(path: String, md5: String) -> PairSnapshotEntry {
        PairSnapshotEntry(path: path, size: 12, modTime: Date(timeIntervalSince1970: 1_234), md5: md5)
    }
}

private actor StubProcessClient: RcloneProcessRunning {
    private let result: (stdout: String, stderr: String, exitCode: Int32)
    private var argumentsLog: [[String]] = []

    init(result: (stdout: String, stderr: String, exitCode: Int32)) {
        self.result = result
    }

    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        argumentsLog.append(arguments)
        return result
    }

    func recordedArguments() -> [[String]] {
        argumentsLog
    }
}

private final class StubExcludeFileStore: RcloneExcludeFilePreparing, @unchecked Sendable {
    private var modes: [RcloneExcludeFileMode] = []

    func prepareExcludeFile(for pair: SyncPair, mode: RcloneExcludeFileMode) throws -> String? {
        modes.append(mode)
        switch mode {
        case .sync:
            return "/tmp/sync-excludes.txt"
        case .check:
            return "/tmp/check-excludes.txt"
        }
    }

    func preparedModes() -> [RcloneExcludeFileMode] {
        modes
    }
}

private struct StubLocalFolderInspector: LocalFolderInspecting {
    let containsUserVisibleContent: Bool

    func containsUserVisibleContent(atPath path: String) throws -> Bool {
        containsUserVisibleContent
    }

    func containsUserVisibleContent(atPath path: String, excludedPatterns: [String]) throws -> Bool {
        containsUserVisibleContent
    }
}

private struct StubSnapshotProvider: PairSnapshotProviding {
    let snapshotsByPath: [String: PairSnapshot]

    func snapshot(for pair: SyncPair, path: String, mode: RcloneExcludeFileMode) async throws -> PairSnapshot {
        snapshotsByPath[path] ?? PairSnapshot(entries: [])
    }
}

private actor RecordingSnapshotProvider: PairSnapshotProviding {
    private let snapshotsByPath: [String: [PairSnapshot]]
    private var requestLog: [String] = []
    private var requestCounts: [String: Int] = [:]

    init(snapshotsByPath: [String: [PairSnapshot]]) {
        self.snapshotsByPath = snapshotsByPath
    }

    func snapshot(for pair: SyncPair, path: String, mode: RcloneExcludeFileMode) async throws -> PairSnapshot {
        requestLog.append(path)
        let index = requestCounts[path, default: 0]
        requestCounts[path] = index + 1

        guard let snapshots = snapshotsByPath[path], !snapshots.isEmpty else {
            return PairSnapshot(entries: [])
        }

        if index < snapshots.count {
            return snapshots[index]
        }

        return snapshots[snapshots.count - 1]
    }

    func requestedPaths() -> [String] {
        requestLog
    }
}

private actor InMemoryBaselineStore: PairConflictStateStoring {
    private var states: [UUID: PairConflictBaselineState]

    init(initialStates: [UUID: PairConflictBaselineState] = [:]) {
        self.states = initialStates
    }

    func load(pairID: UUID) async throws -> PairConflictBaselineState? {
        states[pairID]
    }

    func save(_ state: PairConflictBaselineState) async throws {
        states[state.pairID] = state
    }

    func remove(pairID: UUID) async throws {
        states[pairID] = nil
    }
}

private struct StubRcloneOperationInspector: RcloneOperationInspecting {
    let activeOperation: ActiveRcloneCopyOperation?

    func activeCopyOperation(remotePath: String, localPath: String, configPath: String?) async throws -> ActiveRcloneCopyOperation? {
        activeOperation
    }
}
