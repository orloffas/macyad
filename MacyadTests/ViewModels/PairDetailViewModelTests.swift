import XCTest
@testable import MacyadCore

@MainActor
final class PairDetailViewModelTests: XCTestCase {
    private var viewModel: PairDetailViewModel!

    override func setUp() async throws {
        viewModel = PairDetailViewModel()
    }

    func testPauseSourceNoneWhenBothEnabled() {
        let pair = makePair(autoSyncMode: .push)
        let prefs = AppPreferences.defaults
        XCTAssertEqual(viewModel.pauseSource(for: pair, preferences: prefs), .none)
    }

    func testPauseSourceGlobalWhenGlobalPaused() {
        let pair = makePair(autoSyncMode: .push)
        let prefs = AppPreferences(
            selectedLanguage: "en",
            launchAtLoginEnabled: true,
            defaultScheduleMinutes: 15,
            isGlobalSchedulerPaused: true
        )
        XCTAssertEqual(viewModel.pauseSource(for: pair, preferences: prefs), .global)
    }

    func testPauseSourceGlobalTakesPriorityOverPerPair() {
        let pair = makePair(autoSyncMode: .off)
        let prefs = AppPreferences(
            selectedLanguage: "en",
            launchAtLoginEnabled: true,
            defaultScheduleMinutes: 15,
            isGlobalSchedulerPaused: true
        )
        XCTAssertEqual(viewModel.pauseSource(for: pair, preferences: prefs), .global)
    }

    func testPauseSourcePerPairWhenOnlyPairDisabled() {
        let pair = makePair(autoSyncMode: .off)
        let prefs = AppPreferences.defaults
        XCTAssertEqual(viewModel.pauseSource(for: pair, preferences: prefs), .perPair)
    }

    private func makePair(autoSyncMode: AutoSyncMode) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Test",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/tmp/test",
            remotePath: "yd:/Test",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy,
            autoSyncMode: autoSyncMode
        )
    }

    @MainActor
    func testEachPairKeepsItsOwnOperationPhase() {
        let viewModel = PairDetailViewModel()
        let first = UUID()
        let second = UUID()

        viewModel.setOperationPhase(.queued, for: first, kind: .manual)
        viewModel.setOperationPhase(.queued, for: second, kind: .manual)
        viewModel.setOperationPhase(.running, for: first)
        viewModel.setOperationPhase(.idle, for: first)

        XCTAssertEqual(viewModel.operationPhase(for: first), .idle)
        XCTAssertEqual(viewModel.operationPhase(for: second), .queued, "the first run finishing must not clear the second")
        XCTAssertEqual(viewModel.lastOperationKind(for: second), .manual)
        XCTAssertEqual(viewModel.operationPhase(for: nil), .idle)
    }

    func testNextSyncFollowsTheSchedulerRule() {
        let last = Date(timeIntervalSince1970: 1_000)
        var pair = SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/Users/test/Docs",
            remotePath: "yd:/Docs",
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy,
            lastSyncAt: last,
            autoSyncMode: .push
        )
        let running = AppPreferences.defaults
        var paused = AppPreferences.defaults
        paused.isGlobalSchedulerPaused = true

        XCTAssertEqual(viewModel.nextSync(for: pair, preferences: running), .at(last.addingTimeInterval(900)))
        XCTAssertEqual(viewModel.nextSync(for: pair, preferences: paused), .paused)

        pair.lastKnownSeverity = .alarm
        XCTAssertEqual(viewModel.nextSync(for: pair, preferences: running), .afterManualRun)
        pair.lastFailureIsTransient = true
        XCTAssertEqual(viewModel.nextSync(for: pair, preferences: running), .at(last.addingTimeInterval(900)), "a network failure is retried")

        pair.autoSyncMode = .off
        XCTAssertEqual(viewModel.nextSync(for: pair, preferences: running), .paused)
    }
}
