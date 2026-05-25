import XCTest
@testable import MacyadCore

final class PairActivitySeverityResolverTests: XCTestCase {
    func testDisplaySeverityUsesHighestSeverityAcrossPairEvents() {
        let pair = makePair(severity: .warning)
        let otherPair = makePair(severity: .healthy)
        let resolver = PairActivitySeverityResolver()

        let events = [
            ActivityEvent(id: UUID(), date: Date(), message: "warning", severity: .warning, pairID: pair.id),
            ActivityEvent(id: UUID(), date: Date(), message: "alarm", severity: .alarm, pairID: pair.id),
            ActivityEvent(id: UUID(), date: Date(), message: "other", severity: .alarm, pairID: otherPair.id)
        ]

        XCTAssertEqual(resolver.displaySeverity(for: pair, events: events), .alarm)
    }

    func testDisplaySeverityFallsBackToPairSeverityWithoutEvents() {
        let pair = makePair(severity: .info)
        let resolver = PairActivitySeverityResolver()

        XCTAssertEqual(resolver.displaySeverity(for: pair, events: []), .info)
    }

    private func makePair(severity: Severity) -> SyncPair {
        SyncPair(
            id: UUID(),
            name: "Docs",
            localFolderBookmark: Data("bookmark".utf8),
            localFolderDisplayPath: "/Users/test/Docs",
            remotePath: "yd:/docs",
            scheduleMinutes: 15,
            deletePolicy: .mirrorToYandex,
            lastKnownSeverity: severity
        )
    }
}
