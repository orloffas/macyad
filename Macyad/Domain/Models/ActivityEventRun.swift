import Foundation

public struct ActivityEventRun: Equatable, Identifiable, Sendable {
    public let representative: ActivityEvent
    public let events: [ActivityEvent]

    public init(representative: ActivityEvent, events: [ActivityEvent]) {
        self.representative = representative
        self.events = events
    }

    public var id: UUID {
        representative.id
    }

    public var count: Int {
        events.count
    }

    public var isCollapsedByDefault: Bool {
        count > 1
    }

    public static func makeRuns(from events: [ActivityEvent]) -> [ActivityEventRun] {
        guard var current = events.first else {
            return []
        }

        var currentRun = [current]
        var runs: [ActivityEventRun] = []

        for event in events.dropFirst() {
            if isEquivalentForCollapsedDisplay(lhs: current, rhs: event) {
                currentRun.append(event)
            } else {
                runs.append(ActivityEventRun(representative: current, events: currentRun))
                current = event
                currentRun = [event]
            }
        }

        runs.append(ActivityEventRun(representative: current, events: currentRun))
        return runs
    }

    private static func isEquivalentForCollapsedDisplay(lhs: ActivityEvent, rhs: ActivityEvent) -> Bool {
        lhs.message == rhs.message
            && lhs.severity == rhs.severity
            && lhs.pairID == rhs.pairID
            && lhs.details == rhs.details
            && lhs.issueSet == rhs.issueSet
    }
}
