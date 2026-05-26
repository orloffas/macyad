import XCTest
@testable import MacyadCore

final class SyncServiceTests: XCTestCase {
    func testPushDoesNotRunRcloneWhenLocalFolderIsEmpty() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let processClient = StubProcessClient(result: ("", "", 0))
        let excludeFileStore = StubExcludeFileStore()
        let service = SyncService(
            processClient: processClient,
            configPath: "/tmp/macyad-rclone.conf",
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: false),
            excludeFileStore: excludeFileStore
        )

        let outcome = await service.push(makePair())

        XCTAssertEqual(outcome.severity, .warning)
        XCTAssertEqual(outcome.summary, AppCopy.current.manualPushBlockedTitle)
        XCTAssertTrue(outcome.details?.contains("Local folder is empty") == true)

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
