import XCTest
@testable import MacyadCore

final class ActivityEventRunTests: XCTestCase {
    func testMakeRunsCollapsesConsecutiveEquivalentEvents() {
        let pairID = UUID()
        let first = makeEvent(
            date: Date(timeIntervalSince1970: 300),
            message: "Scheduled Push to Yandex completed",
            severity: .healthy,
            pairID: pairID
        )
        let second = makeEvent(
            date: Date(timeIntervalSince1970: 200),
            message: "Scheduled Push to Yandex completed",
            severity: .healthy,
            pairID: pairID
        )
        let third = makeEvent(
            date: Date(timeIntervalSince1970: 100),
            message: "Push to Yandex blocked",
            severity: .warning,
            pairID: pairID
        )

        let runs = ActivityEventRun.makeRuns(from: [first, second, third])

        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs[0].count, 2)
        XCTAssertEqual(runs[0].representative.id, first.id)
        XCTAssertEqual(runs[0].events.map(\.id), [first.id, second.id])
        XCTAssertTrue(runs[0].isCollapsedByDefault)
        XCTAssertEqual(runs[1].count, 1)
    }

    func testMakeRunsDoesNotCollapseSeparatedRepeats() {
        let pairID = UUID()
        let first = makeEvent(
            date: Date(timeIntervalSince1970: 300),
            message: "Scheduled Push to Yandex completed",
            severity: .healthy,
            pairID: pairID
        )
        let middle = makeEvent(
            date: Date(timeIntervalSince1970: 200),
            message: "Push to Yandex blocked",
            severity: .warning,
            pairID: pairID
        )
        let last = makeEvent(
            date: Date(timeIntervalSince1970: 100),
            message: "Scheduled Push to Yandex completed",
            severity: .healthy,
            pairID: pairID
        )

        let runs = ActivityEventRun.makeRuns(from: [first, middle, last])

        XCTAssertEqual(runs.count, 3)
        XCTAssertEqual(runs.map(\.count), [1, 1, 1])
    }

    func testMakeRunsDoesNotCollapseEventsWithDifferentDetails() {
        let pairID = UUID()
        let first = makeEvent(
            date: Date(timeIntervalSince1970: 300),
            message: "Push to Yandex blocked",
            severity: .warning,
            pairID: pairID,
            details: "draft.txt differs"
        )
        let second = makeEvent(
            date: Date(timeIntervalSince1970: 200),
            message: "Push to Yandex blocked",
            severity: .warning,
            pairID: pairID,
            details: "report.txt differs"
        )

        let runs = ActivityEventRun.makeRuns(from: [first, second])

        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs.map(\.count), [1, 1])
    }

    private func makeEvent(
        date: Date,
        message: String,
        severity: Severity,
        pairID: UUID?,
        details: String? = nil
    ) -> ActivityEvent {
        ActivityEvent(
            id: UUID(),
            date: date,
            message: message,
            severity: severity,
            pairID: pairID,
            details: details
        )
    }
}
