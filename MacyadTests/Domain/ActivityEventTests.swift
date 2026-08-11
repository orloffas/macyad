import XCTest
@testable import MacyadCore

final class ActivityEventTests: XCTestCase {
    func testDecodesLegacyEventWithoutDetails() throws {
        let id = UUID()
        let pairID = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "date": 1716580800,
          "message": "Legacy warning",
          "severity": "warning",
          "pairID": "\(pairID.uuidString)"
        }
        """

        let event = try JSONDecoder().decode(ActivityEvent.self, from: Data(json.utf8))

        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.message, "Legacy warning")
        XCTAssertEqual(event.severity, .warning)
        XCTAssertEqual(event.pairID, pairID)
        XCTAssertNil(event.details)
    }

    func testDetailsRoundTrip() throws {
        let event = ActivityEvent(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_716_580_800),
            message: "Push to Yandex blocked",
            severity: .warning,
            pairID: UUID(),
            details: "Local folder is empty. Run Pull From Yandex first."
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: data)

        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.details, "Local folder is empty. Run Pull From Yandex first.")
    }

    func testIssueSetAndRouteTokenRoundTrip() throws {
        let pairID = UUID()
        let eventID = UUID()
        let event = ActivityEvent(
            id: eventID,
            date: Date(timeIntervalSince1970: 1_716_580_800),
            message: "Push to Yandex blocked",
            severity: .warning,
            pairID: pairID,
            details: "Structured review required.",
            issueSet: ActivityIssueSet(
                issues: [
                    ActivityFileIssue(
                        relativePath: "Docs/test.txt",
                        problemKind: .remoteOnlyChanged,
                        differences: [.sizeDiffers, .mtimeDiffers],
                        localSnapshot: PairSnapshotEntry(path: "Docs/test.txt", size: 12, modTime: Date(timeIntervalSince1970: 1_000), md5: "local"),
                        remoteSnapshot: PairSnapshotEntry(path: "Docs/test.txt", size: 18, modTime: Date(timeIntervalSince1970: 2_000), md5: "remote"),
                        baselineSnapshot: PairSnapshotEntry(path: "Docs/test.txt", size: 12, modTime: Date(timeIntervalSince1970: 900), md5: "base"),
                        selectedDecision: .later
                    )
                ]
            ),
            routeToken: ActivityRouteToken(pairID: pairID, eventID: eventID, openIssueTable: false)
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: data)

        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.issueSet?.issues.first?.fileName, "test.txt")
        XCTAssertEqual(decoded.routeToken?.eventID, eventID)
    }

    func testLegacyEventIsNotTreatedAsInFlight() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "date": 1716580800,
          "message": "Legacy warning",
          "severity": "warning",
          "pairID": "\(UUID().uuidString)"
        }
        """

        let event = try JSONDecoder().decode(ActivityEvent.self, from: Data(json.utf8))

        XCTAssertNil(event.inFlightOperation)
        XCTAssertNil(event.interrupted(using: AppCopy(language: .english)))
    }

    func testInFlightEventBecomesInterrupted() {
        let pairID = UUID()
        let eventID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_716_580_800)
        let recoveredAt = Date(timeIntervalSince1970: 1_716_584_400)
        let copy = AppCopy(language: .english)
        let started = ActivityEvent(
            id: eventID,
            date: startedAt,
            message: copy.operationStartedMessage("Pull from Yandex"),
            severity: .info,
            pairID: pairID,
            inFlightOperation: "Pull from Yandex"
        )

        let interrupted = started.interrupted(using: copy, at: recoveredAt)

        XCTAssertEqual(interrupted?.id, eventID)
        XCTAssertEqual(interrupted?.pairID, pairID)
        XCTAssertEqual(interrupted?.date, recoveredAt)
        XCTAssertEqual(interrupted?.severity, .warning)
        XCTAssertEqual(interrupted?.message, copy.operationInterruptedMessage("Pull from Yandex"))
        XCTAssertEqual(interrupted?.details, copy.operationInterruptedDetails)
        XCTAssertNil(interrupted?.inFlightOperation)
    }

    func testMarkingInterruptedRunsSparesRunsStartedByThisLaunch() {
        let copy = AppCopy(language: .english)
        let launchedAt = Date(timeIntervalSince1970: 1_716_580_800)
        let startedByThisLaunch = ActivityEvent(
            id: UUID(),
            date: launchedAt.addingTimeInterval(30),
            message: copy.operationStartedMessage("Push to Yandex"),
            severity: .info,
            pairID: UUID(),
            inFlightOperation: "Push to Yandex"
        )

        let recovered = [startedByThisLaunch].markingInterruptedRuns(using: copy, startedBefore: launchedAt)

        XCTAssertEqual(recovered, [startedByThisLaunch])
    }

    func testMarkingInterruptedRunsLeavesFinishedEventsAlone() {
        let copy = AppCopy(language: .english)
        let finished = ActivityEvent(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_716_580_800),
            message: "Pull from Yandex completed",
            severity: .healthy,
            pairID: UUID()
        )
        let inFlight = ActivityEvent(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_716_580_900),
            message: copy.operationStartedMessage("Push to Yandex"),
            severity: .info,
            pairID: UUID(),
            inFlightOperation: "Push to Yandex"
        )

        let recovered = [finished, inFlight].markingInterruptedRuns(
            using: copy,
            startedBefore: Date(timeIntervalSince1970: 1_716_581_000)
        )

        XCTAssertEqual(recovered.count, 2)
        XCTAssertEqual(recovered[0], finished)
        XCTAssertEqual(recovered[1].severity, .warning)
        XCTAssertNil(recovered[1].inFlightOperation)
    }

    func testInFlightOperationSurvivesRoundTrip() throws {
        let event = ActivityEvent(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1_716_580_800),
            message: "Pull from Yandex: running…",
            severity: .info,
            pairID: UUID(),
            inFlightOperation: "Pull from Yandex"
        )

        let decoded = try JSONDecoder().decode(ActivityEvent.self, from: JSONEncoder().encode(event))

        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.inFlightOperation, "Pull from Yandex")
    }
}
