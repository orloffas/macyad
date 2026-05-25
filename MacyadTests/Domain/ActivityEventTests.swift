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
}
