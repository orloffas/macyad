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
}
