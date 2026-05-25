import Foundation
import XCTest
@testable import MacyadCore

final class ActivityRepositoryTests: XCTestCase {
    func testLoadPrunesEventsOlderThan48HoursAndPersistsTrimmedData() async throws {
        let now = Date(timeIntervalSince1970: 1_716_580_800)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storeURL = rootURL.appendingPathComponent("activity.json")
        let store = JSONFileStore<[ActivityEvent]>(url: storeURL)
        let staleEvent = ActivityEvent(
            id: UUID(),
            date: now.addingTimeInterval(-(49 * 60 * 60)),
            message: "Old warning",
            severity: .warning,
            pairID: nil,
            details: "stale"
        )
        let freshEvent = ActivityEvent(
            id: UUID(),
            date: now.addingTimeInterval(-(2 * 60 * 60)),
            message: "Fresh warning",
            severity: .warning,
            pairID: nil,
            details: "fresh"
        )
        try await store.save([staleEvent, freshEvent])

        let repository = ActivityRepository(
            store: store,
            now: { now }
        )

        let loadedEvents = try await repository.load()
        let persistedEvents = try await store.load(default: [])

        XCTAssertEqual(loadedEvents, [freshEvent])
        XCTAssertEqual(persistedEvents, [freshEvent])
    }
}
