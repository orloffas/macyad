import XCTest
@testable import MacyadCore

@MainActor
final class OverviewViewModelTests: XCTestCase {
    private let copy = AppCopy(language: .english)

    private func makePair(
        id: UUID = UUID(),
        name: String = "Pair",
        severity: Severity = .healthy,
        lastSyncAt: Date? = nil,
        isAutoPushEnabled: Bool = true
    ) -> SyncPair {
        SyncPair(
            id: id,
            name: name,
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/tmp",
            remotePath: "yd:/path",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity,
            lastSyncAt: lastSyncAt,
            isAutoPushEnabled: isAutoPushEnabled
        )
    }

    private func makeEvent(pairID: UUID, severity: Severity, date: Date = Date()) -> ActivityEvent {
        ActivityEvent(id: UUID(), date: date, message: "test", severity: severity, pairID: pairID)
    }

    private var defaultPrefs: AppPreferences {
        AppPreferences(selectedLanguage: "en", launchAtLoginEnabled: false, defaultScheduleMinutes: 15, isGlobalSchedulerPaused: false)
    }

    func testThreePairsProduceThreeRowsInOrder() {
        let pairA = makePair(name: "Alpha")
        let pairB = makePair(name: "Beta")
        let pairC = makePair(name: "Gamma")
        let vm = OverviewViewModel()

        vm.update(pairs: [pairA, pairB, pairC], events: [], preferences: defaultPrefs, copy: copy)

        XCTAssertEqual(vm.rows.count, 3)
        XCTAssertEqual(vm.rows[0].name, "Alpha")
        XCTAssertEqual(vm.rows[1].name, "Beta")
        XCTAssertEqual(vm.rows[2].name, "Gamma")
    }

    func testRowReflectsIsAutoPushDisabled() {
        let pair = makePair(isAutoPushEnabled: false)
        let vm = OverviewViewModel()

        vm.update(pairs: [pair], events: [], preferences: defaultPrefs, copy: copy)

        XCTAssertFalse(vm.rows[0].isAutoPushEnabled)
        XCTAssertTrue(vm.rows[0].isPaused)
    }

    func testGlobalPauseMarksAllRowsPaused() {
        let pairA = makePair(isAutoPushEnabled: true)
        let pairB = makePair(isAutoPushEnabled: true)
        let pausedPrefs = AppPreferences(selectedLanguage: "en", launchAtLoginEnabled: false, defaultScheduleMinutes: 15, isGlobalSchedulerPaused: true)
        let vm = OverviewViewModel()

        vm.update(pairs: [pairA, pairB], events: [], preferences: pausedPrefs, copy: copy)

        XCTAssertTrue(vm.rows[0].isGloballyPaused)
        XCTAssertTrue(vm.rows[0].isPaused)
        XCTAssertTrue(vm.rows[1].isGloballyPaused)
        XCTAssertTrue(vm.rows[1].isPaused)
    }

    func testSeverityFromLatestEvent() {
        let pair = makePair(severity: .healthy)
        let oldEvent = makeEvent(pairID: pair.id, severity: .info, date: Date(timeIntervalSince1970: 1000))
        let newEvent = makeEvent(pairID: pair.id, severity: .alarm, date: Date(timeIntervalSince1970: 2000))
        let vm = OverviewViewModel()

        vm.update(pairs: [pair], events: [oldEvent, newEvent], preferences: defaultPrefs, copy: copy)

        XCTAssertEqual(vm.rows[0].severity, .alarm)
    }

    func testSeverityFallsBackToPairWhenNoEvents() {
        let pair = makePair(severity: .warning)
        let vm = OverviewViewModel()

        vm.update(pairs: [pair], events: [], preferences: defaultPrefs, copy: copy)

        XCTAssertEqual(vm.rows[0].severity, .warning)
    }

    func testLastSyncTitleNeverSyncedWhenNoDate() {
        let pair = makePair(lastSyncAt: nil)
        let vm = OverviewViewModel()

        vm.update(pairs: [pair], events: [], preferences: defaultPrefs, copy: copy)

        XCTAssertEqual(vm.rows[0].lastSyncTitle, copy.neverSynced)
    }

    func testLastSyncTitleFormattedWhenDatePresent() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let pair = makePair(lastSyncAt: date)
        let vm = OverviewViewModel()

        vm.update(pairs: [pair], events: [], preferences: defaultPrefs, copy: copy)

        XCTAssertEqual(vm.rows[0].lastSyncTitle, copy.formatTimestamp(date))
    }

    func testEventsFromOtherPairsDoNotAffectSeverity() {
        let pairA = makePair(severity: .healthy)
        let pairB = makePair(severity: .info)
        let eventForB = makeEvent(pairID: pairB.id, severity: .alarm)
        let vm = OverviewViewModel()

        vm.update(pairs: [pairA, pairB], events: [eventForB], preferences: defaultPrefs, copy: copy)

        XCTAssertEqual(vm.rows[0].severity, .healthy)
        XCTAssertEqual(vm.rows[1].severity, .alarm)
    }
}
