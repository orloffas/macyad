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

    func testEnsureViewModel_returnsSameInstanceOnRepeatedCalls() {
        let first = mock.ensureViewModel(for: pairA.id)
        let second = mock.ensureViewModel(for: pairA.id)

        XCTAssertTrue(first === second)
    }

    func testEnsureViewModel_makesViewModelAvailableViaLookup() {
        XCTAssertNil(mock.viewModel(for: pairA.id))
        XCTAssertFalse(mock.hasLog(for: pairA.id))

        let vm = mock.ensureViewModel(for: pairA.id)

        XCTAssertTrue(mock.viewModel(for: pairA.id) === vm)
        XCTAssertTrue(mock.hasLog(for: pairA.id))
    }

    func testPresentOnce_addsOneEntryAndStoresViewModel() {
        mock.present(pair: pairA, copy: copy)

        XCTAssertEqual(mock.openedWindows.count, 1)
        XCTAssertTrue(mock.openedWindows.contains(pairA.id))
        XCTAssertNotNil(mock.viewModel(for: pairA.id))
    }

    func testPresentTwiceSamePair_stillOneEntry_viewModelReused() {
        mock.present(pair: pairA, copy: copy)
        let firstVM = mock.viewModel(for: pairA.id)
        mock.present(pair: pairA, copy: copy)

        XCTAssertEqual(mock.openedWindows.count, 1)
        XCTAssertTrue(mock.viewModel(for: pairA.id) === firstVM)
    }

    func testClose_removesWindowButKeepsViewModel() {
        mock.present(pair: pairA, copy: copy)
        let vm = mock.viewModel(for: pairA.id)
        mock.close(pairID: pairA.id)

        XCTAssertTrue(mock.openedWindows.isEmpty)
        XCTAssertNotNil(mock.viewModel(for: pairA.id), "view-model should persist across close")
        XCTAssertTrue(mock.viewModel(for: pairA.id) === vm)
    }

    func testReopenAfterClose_reusesStoredViewModel() {
        mock.present(pair: pairA, copy: copy)
        let firstVM = mock.viewModel(for: pairA.id)
        mock.close(pairID: pairA.id)
        mock.present(pair: pairA, copy: copy)

        XCTAssertEqual(mock.openedWindows.count, 1)
        XCTAssertTrue(mock.viewModel(for: pairA.id) === firstVM)
    }

    func testPresentTwoPairs_closeOne_otherWindowRemains_bothViewModelsKept() {
        mock.present(pair: pairA, copy: copy)
        mock.present(pair: pairB, copy: copy)
        mock.close(pairID: pairA.id)

        XCTAssertEqual(mock.openedWindows.count, 1)
        XCTAssertTrue(mock.openedWindows.contains(pairB.id))
        XCTAssertNotNil(mock.viewModel(for: pairA.id))
        XCTAssertNotNil(mock.viewModel(for: pairB.id))
    }

    func testViewModelsForDifferentPairsAreDistinct() {
        let vmA = mock.ensureViewModel(for: pairA.id)
        let vmB = mock.ensureViewModel(for: pairB.id)

        XCTAssertFalse(vmA === vmB)
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
