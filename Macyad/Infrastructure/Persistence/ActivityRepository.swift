import Foundation

public actor ActivityRepository {
    private let store: JSONFileStore<[ActivityEvent]>
    private let now: @Sendable () -> Date
    private let retentionInterval: TimeInterval

    init(
        store: JSONFileStore<[ActivityEvent]>,
        now: @escaping @Sendable () -> Date = Date.init,
        retentionInterval: TimeInterval = 48 * 60 * 60
    ) {
        self.store = store
        self.now = now
        self.retentionInterval = retentionInterval
    }

    public init(
        paths: AppPaths,
        now: @escaping @Sendable () -> Date = Date.init,
        retentionInterval: TimeInterval = 48 * 60 * 60
    ) {
        self.store = JSONFileStore(url: paths.activityFile)
        self.now = now
        self.retentionInterval = retentionInterval
    }

    public func load() async throws -> [ActivityEvent] {
        let events = try await store.load(default: [])
        let prunedEvents = prune(events)

        if prunedEvents != events {
            try await store.save(prunedEvents)
        }

        return prunedEvents
    }

    public func save(_ events: [ActivityEvent]) async throws {
        try await store.save(prune(events))
    }

    public func append(_ event: ActivityEvent) async throws {
        var events = try await load()
        events.append(event)
        try await save(events)
    }

    public func replace(_ event: ActivityEvent) async throws {
        var events = try await load()
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
        try await save(events)
    }

    public func events(for pairID: UUID?) async throws -> [ActivityEvent] {
        let events = try await load().sorted { $0.date > $1.date }
        guard let pairID else {
            return events
        }

        return events.filter { $0.pairID == pairID }
    }

    private func prune(_ events: [ActivityEvent]) -> [ActivityEvent] {
        let cutoffDate = now().addingTimeInterval(-retentionInterval)
        return events.filter { $0.date >= cutoffDate }
    }
}
