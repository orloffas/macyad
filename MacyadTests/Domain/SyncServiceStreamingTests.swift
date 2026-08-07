import XCTest
@testable import MacyadCore

final class SyncServiceStreamingTests: XCTestCase {
    func testPushWithObserverCollectsLinesInOrder() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let lines = ["line1", "line2", "line3"]
        let processClient = StreamingStubProcessClient(lines: lines, result: ("", "", 0))
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
            baselineRepository: InMemoryBaselineStore()
        )
        let observer = CollectingObserver()

        let outcome = await service.push(pair, observer: observer)

        XCTAssertEqual(outcome.severity, Severity.healthy)
        let collected = await observer.collected
        XCTAssertTrue(collected.first?.contains("macyad : ——— starting rclone (sync)") == true,
                      "missing start marker, got: \(collected.first ?? "<none>")")
        XCTAssertTrue(collected[1].contains("macyad : command: rclone sync"),
                      "missing command marker, got: \(collected[1])")
        XCTAssertEqual(collected.filter { !$0.isMacyadMarker }, lines)
        XCTAssertTrue(collected.contains { $0.contains("macyad : ——— rclone exited with code 0 ———") },
                      "missing end marker in: \(collected.filter(\.isMacyadMarker))")
        XCTAssertTrue(collected.last?.contains("macyad : refreshing baseline snapshot after rclone") == true,
                      "baseline refresh marker must come last, got: \(collected.last ?? "<none>")")
    }

    func testPushWithNilObserverUsesNonStreamingPath() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let processClient = StreamingStubProcessClient(lines: ["line1"], result: ("", "", 0))
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
            baselineRepository: InMemoryBaselineStore()
        )

        let outcome = await service.push(pair, observer: (nil as RcloneOutputObserver?))

        XCTAssertEqual(outcome.severity, Severity.healthy)
        let runCount = await processClient.runCallCount
        let streamCount = await processClient.runStreamingCallCount
        XCTAssertEqual(runCount, 1)
        XCTAssertEqual(streamCount, 0)
    }

    func testPushObserverReceivesAllLinesNoDropStress() async throws {
        let previousLanguage = AppLanguageState.current
        AppLanguageState.update(.english)
        defer { AppLanguageState.update(previousLanguage) }

        let pair = makePair()
        let count = 1000
        let lines = (0..<count).map { "line\($0)" }
        let processClient = StreamingStubProcessClient(lines: lines, result: ("", "", 0))
        let service = SyncService(
            processClient: processClient,
            localFolderInspector: StubLocalFolderInspector(containsUserVisibleContent: true),
            snapshotProvider: StubSnapshotProvider(snapshotsByPath: cleanSnapshots(for: [pair])),
            baselineRepository: InMemoryBaselineStore()
        )
        let observer = CollectingObserver()

        await service.push(pair, observer: observer)

        let collected = await observer.collected
        XCTAssertEqual(collected.filter { !$0.isMacyadMarker }, lines)
    }

    // MARK: - Helpers

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
}

private extension String {
    /// Строки, которые дописывает сам macyad вокруг вывода rclone: стартовый и
    /// командный маркеры, код выхода, refresh baseline. Тесты отбирают вывод
    /// rclone по этому признаку, а не по позиции, чтобы новый маркер их не ломал.
    var isMacyadMarker: Bool { contains("macyad : ") }
}

private actor CollectingObserver: RcloneOutputObserver {
    private(set) var collected: [String] = []

    func onLine(_ line: String) async {
        collected.append(line)
    }
}

private actor StreamingStubProcessClient: RcloneProcessRunning {
    private let lines: [String]
    private let result: (stdout: String, stderr: String, exitCode: Int32)
    private(set) var runCallCount = 0
    private(set) var runStreamingCallCount = 0

    init(lines: [String], result: (stdout: String, stderr: String, exitCode: Int32)) {
        self.lines = lines
        self.result = result
    }

    func run(_ arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        runCallCount += 1
        return result
    }

    func runStreaming(_ arguments: [String]) async throws -> RcloneStreamingHandle {
        runStreamingCallCount += 1
        let capturedLines = lines
        let capturedResult = result
        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        let completionTask = Task<(stdout: String, stderr: String, exitCode: Int32), Error> {
            for line in capturedLines {
                continuation.yield(line)
            }
            continuation.finish()
            return capturedResult
        }
        return RcloneStreamingHandle(lines: stream, completion: completionTask)
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

private final class StubLocalFolderInspector: LocalFolderInspecting, @unchecked Sendable {
    let containsUserVisibleContent: Bool

    init(containsUserVisibleContent: Bool) {
        self.containsUserVisibleContent = containsUserVisibleContent
    }

    func containsUserVisibleContent(atPath path: String) throws -> Bool {
        containsUserVisibleContent
    }

    func containsUserVisibleContent(atPath path: String, excludedPatterns: [String]) throws -> Bool {
        containsUserVisibleContent
    }
}
