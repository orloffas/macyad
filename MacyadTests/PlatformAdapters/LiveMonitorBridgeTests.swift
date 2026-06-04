import XCTest
@testable import MacyadCore

@MainActor
final class LiveMonitorBridgeTests: XCTestCase {
    private var mock: LiveMonitorPresentingMock!
    private var pairA: SyncPair!
    private var pairB: SyncPair!
    private let copy = AppCopy(language: .english)

    override func setUp() async throws {
        mock = LiveMonitorPresentingMock()
        pairA = makePair(name: "PairA")
        pairB = makePair(name: "PairB")
    }

    func testEnsureRunningViewModel_returnsSameInstanceOnRepeatedCalls() {
        let first = mock.ensureRunningViewModel(for: pairA.id)
        let second = mock.ensureRunningViewModel(for: pairA.id)

        XCTAssertTrue(first === second)
    }

    func testHasRunningAndArchivedLog_initiallyFalse() {
        XCTAssertFalse(mock.hasRunningLog(for: pairA.id))
        XCTAssertFalse(mock.hasArchivedLog(for: pairA.id))
    }

    func testEnsureRunning_setsHasRunningButNotArchived() {
        _ = mock.ensureRunningViewModel(for: pairA.id)

        XCTAssertTrue(mock.hasRunningLog(for: pairA.id))
        XCTAssertFalse(mock.hasArchivedLog(for: pairA.id))
    }

    func testArchiveRunningLog_movesViewModelToArchivedSlot() {
        let runningVM = mock.ensureRunningViewModel(for: pairA.id)
        mock.archiveRunningLog(for: pairA.id)

        XCTAssertFalse(mock.hasRunningLog(for: pairA.id))
        XCTAssertTrue(mock.hasArchivedLog(for: pairA.id))
        XCTAssertTrue(mock.viewModel(for: pairA.id, slot: .archived) === runningVM)
    }

    func testArchiveTwice_secondArchiveReplacesFirst() {
        let firstVM = mock.ensureRunningViewModel(for: pairA.id)
        mock.archiveRunningLog(for: pairA.id)
        let secondVM = mock.ensureRunningViewModel(for: pairA.id)
        XCTAssertFalse(firstVM === secondVM)
        mock.archiveRunningLog(for: pairA.id)

        XCTAssertTrue(mock.viewModel(for: pairA.id, slot: .archived) === secondVM)
    }

    func testArchiveWithoutRunning_isNoOp() {
        mock.archiveRunningLog(for: pairA.id)

        XCTAssertFalse(mock.hasArchivedLog(for: pairA.id))
    }

    func testPresentRunning_noOpWhenSlotEmpty() {
        mock.present(pair: pairA, slot: .running, copy: copy)

        XCTAssertNil(mock.openedWindows[pairA.id])
    }

    func testPresentRunning_opensWindowWhenSlotPopulated() {
        _ = mock.ensureRunningViewModel(for: pairA.id)
        mock.present(pair: pairA, slot: .running, copy: copy)

        XCTAssertEqual(mock.openedWindows[pairA.id], [.running])
    }

    func testPresentArchived_opensSeparateWindow() {
        _ = mock.ensureRunningViewModel(for: pairA.id)
        mock.archiveRunningLog(for: pairA.id)
        _ = mock.ensureRunningViewModel(for: pairA.id)
        mock.present(pair: pairA, slot: .running, copy: copy)
        mock.present(pair: pairA, slot: .archived, copy: copy)

        XCTAssertEqual(mock.openedWindows[pairA.id], [.running, .archived])
    }

    func testCloseRunning_doesNotAffectArchived() {
        _ = mock.ensureRunningViewModel(for: pairA.id)
        mock.archiveRunningLog(for: pairA.id)
        _ = mock.ensureRunningViewModel(for: pairA.id)
        mock.present(pair: pairA, slot: .running, copy: copy)
        mock.present(pair: pairA, slot: .archived, copy: copy)

        mock.close(pairID: pairA.id, slot: .running)

        XCTAssertEqual(mock.openedWindows[pairA.id], [.archived])
    }

    func testViewModelsPerPairAreDistinct() {
        let a = mock.ensureRunningViewModel(for: pairA.id)
        let b = mock.ensureRunningViewModel(for: pairB.id)

        XCTAssertFalse(a === b)
    }

    // MARK: - Helpers

    private func makePair(name: String) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/tmp/\(name)",
            remotePath: "yd:/\(name)",
            scheduleMinutes: 30,
            deletePolicy: .keepRemoteDeletesManual,
            lastKnownSeverity: .healthy
        )
    }
}
