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

    func testPresentOnce_addsOneEntry() {
        mock.present(pair: pairA, viewModel: LiveMonitorViewModel(), copy: copy, restartIfExisting: false)

        XCTAssertEqual(mock.openedWindows.count, 1)
        XCTAssertTrue(mock.openedWindows.contains(pairA.id))
    }

    func testPresentTwiceSamePair_stillOneEntry_viewModelNotReplaced() {
        let vm1 = LiveMonitorViewModel()
        let vm2 = LiveMonitorViewModel()
        mock.present(pair: pairA, viewModel: vm1, copy: copy, restartIfExisting: false)
        mock.present(pair: pairA, viewModel: vm2, copy: copy, restartIfExisting: false)

        XCTAssertEqual(mock.openedWindows.count, 1)
        XCTAssertTrue(mock.viewModels[pairA.id] === vm1)
    }

    func testPresentWithRestartIfExisting_recordsFlag() {
        mock.present(pair: pairA, viewModel: LiveMonitorViewModel(), copy: copy, restartIfExisting: false)
        mock.present(pair: pairA, viewModel: LiveMonitorViewModel(), copy: copy, restartIfExisting: true)

        XCTAssertEqual(mock.lastRestartIfExisting[pairA.id], true)
    }

    func testClose_removesEntry() {
        mock.present(pair: pairA, viewModel: LiveMonitorViewModel(), copy: copy, restartIfExisting: false)
        mock.close(pairID: pairA.id)

        XCTAssertTrue(mock.openedWindows.isEmpty)
        XCTAssertNil(mock.viewModels[pairA.id])
    }

    func testPresentTwoPairs_closeOne_onlyOtherRemains() {
        mock.present(pair: pairA, viewModel: LiveMonitorViewModel(), copy: copy, restartIfExisting: false)
        mock.present(pair: pairB, viewModel: LiveMonitorViewModel(), copy: copy, restartIfExisting: false)
        mock.close(pairID: pairA.id)

        XCTAssertEqual(mock.openedWindows.count, 1)
        XCTAssertTrue(mock.openedWindows.contains(pairB.id))
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
