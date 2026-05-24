import XCTest
@testable import MacyadCore

final class StatusServiceTests: XCTestCase {
    func testSetupRequiredWhenOnboardingNotComplete() {
        let service = StatusService()

        let summary = service.makeSummary(onboardingStep: .installRclone, pairs: [])

        XCTAssertEqual(summary.title, "Setup required")
        XCTAssertEqual(summary.alarmCount, 0)
        XCTAssertEqual(summary.warningCount, 0)
    }

    func testAttentionRequiredWhenAnyPairIsInAlarm() {
        let service = StatusService()
        let pairs = [
            SyncPair(
                id: UUID(),
                name: "Docs",
                localFolderBookmark: Data(),
                localFolderDisplayPath: "/tmp/Docs",
                remotePath: "yd:/Docs",
                scheduleMinutes: 30,
                deletePolicy: .mirrorToYandex,
                lastKnownSeverity: .warning
            ),
            SyncPair(
                id: UUID(),
                name: "Photos",
                localFolderBookmark: Data(),
                localFolderDisplayPath: "/tmp/Photos",
                remotePath: "yd:/Photos",
                scheduleMinutes: 60,
                deletePolicy: .keepRemoteDeletesManual,
                lastKnownSeverity: .alarm
            )
        ]

        let summary = service.makeSummary(onboardingStep: .complete, pairs: pairs)

        XCTAssertEqual(summary.title, "Attention required")
        XCTAssertEqual(summary.alarmCount, 1)
        XCTAssertEqual(summary.warningCount, 1)
    }
}
