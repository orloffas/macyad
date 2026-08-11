import XCTest
@testable import MacyadCore

final class ScheduledSyncEligibilityPolicyTests: XCTestCase {
    private let policy = ScheduledSyncEligibilityPolicy()

    func testPairWithAutoSyncOffReturnsFalse() {
        let pair = makePair(autoSyncMode: .off, severity: .healthy)
        XCTAssertFalse(policy.canRunScheduledSync(for: pair))
    }

    func testPairWithAlarmSeverityReturnsFalse() {
        XCTAssertFalse(policy.canRunScheduledSync(for: makePair(autoSyncMode: .push, severity: .alarm)))
        XCTAssertFalse(policy.canRunScheduledSync(for: makePair(autoSyncMode: .pull, severity: .alarm)))
    }

    func testPairWithAutoPushAndHealthySeverityReturnsTrue() {
        let pair = makePair(autoSyncMode: .push, severity: .healthy)
        XCTAssertTrue(policy.canRunScheduledSync(for: pair))
    }

    func testPairWithAutoPullAndHealthySeverityReturnsTrue() {
        let pair = makePair(autoSyncMode: .pull, severity: .healthy)
        XCTAssertTrue(policy.canRunScheduledSync(for: pair))
    }

    func testPairWithAutoSyncOffAndAlarmReturnsFalse() {
        let pair = makePair(autoSyncMode: .off, severity: .alarm)
        XCTAssertFalse(policy.canRunScheduledSync(for: pair))
    }

    private func makePair(autoSyncMode: AutoSyncMode, severity: Severity) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Test",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/tmp/test",
            remotePath: "yd:/Test",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity,
            autoSyncMode: autoSyncMode
        )
    }
}
