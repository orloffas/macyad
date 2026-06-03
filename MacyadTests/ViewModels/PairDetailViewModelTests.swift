import XCTest
@testable import MacyadCore

@MainActor
final class PairDetailViewModelTests: XCTestCase {
    private var viewModel: PairDetailViewModel!

    override func setUp() async throws {
        viewModel = PairDetailViewModel()
    }

    func testPauseSourceNoneWhenBothEnabled() {
        let pair = makePair(isAutoPushEnabled: true)
        let prefs = AppPreferences.defaults
        XCTAssertEqual(viewModel.pauseSource(for: pair, preferences: prefs), .none)
    }

    func testPauseSourceGlobalWhenGlobalPaused() {
        let pair = makePair(isAutoPushEnabled: true)
        let prefs = AppPreferences(
            selectedLanguage: "en",
            launchAtLoginEnabled: true,
            defaultScheduleMinutes: 15,
            isGlobalSchedulerPaused: true
        )
        XCTAssertEqual(viewModel.pauseSource(for: pair, preferences: prefs), .global)
    }

    func testPauseSourceGlobalTakesPriorityOverPerPair() {
        let pair = makePair(isAutoPushEnabled: false)
        let prefs = AppPreferences(
            selectedLanguage: "en",
            launchAtLoginEnabled: true,
            defaultScheduleMinutes: 15,
            isGlobalSchedulerPaused: true
        )
        XCTAssertEqual(viewModel.pauseSource(for: pair, preferences: prefs), .global)
    }

    func testPauseSourcePerPairWhenOnlyPairDisabled() {
        let pair = makePair(isAutoPushEnabled: false)
        let prefs = AppPreferences.defaults
        XCTAssertEqual(viewModel.pauseSource(for: pair, preferences: prefs), .perPair)
    }

    private func makePair(isAutoPushEnabled: Bool) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Test",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/tmp/test",
            remotePath: "yd:/Test",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: .healthy,
            isAutoPushEnabled: isAutoPushEnabled
        )
    }
}
