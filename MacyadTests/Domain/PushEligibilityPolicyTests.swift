import XCTest
@testable import MacyadCore

final class PushEligibilityPolicyTests: XCTestCase {
    private let policy = PushEligibilityPolicy()

    func testPairWithAutoPushDisabledReturnsFalse() {
        let pair = makePair(isAutoPushEnabled: false, severity: .healthy)
        XCTAssertFalse(policy.canRunScheduledPush(for: pair))
    }

    func testPairWithAlarmSeverityReturnsFalse() {
        let pair = makePair(isAutoPushEnabled: true, severity: .alarm)
        XCTAssertFalse(policy.canRunScheduledPush(for: pair))
    }

    func testPairWithAutoPushEnabledAndHealthySeverityReturnsTrue() {
        let pair = makePair(isAutoPushEnabled: true, severity: .healthy)
        XCTAssertTrue(policy.canRunScheduledPush(for: pair))
    }

    func testPairWithAutoPushDisabledAndAlarmReturnsFalse() {
        let pair = makePair(isAutoPushEnabled: false, severity: .alarm)
        XCTAssertFalse(policy.canRunScheduledPush(for: pair))
    }

    private func makePair(isAutoPushEnabled: Bool, severity: Severity) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Test",
            localFolderBookmark: Data(),
            localFolderDisplayPath: "/tmp/test",
            remotePath: "yd:/Test",
            scheduleMinutes: 30,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity,
            isAutoPushEnabled: isAutoPushEnabled
        )
    }
}
