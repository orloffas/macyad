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
}
