import Foundation

public actor ActivityRepository {
    private let store: JSONFileStore<[ActivityEvent]>

    init(store: JSONFileStore<[ActivityEvent]>) {
        self.store = store
    }

    public init(paths: AppPaths) {
        self.store = JSONFileStore(url: paths.activityFile)
    }

    public func load() async throws -> [ActivityEvent] {
        try await store.load(default: [])
    }

    public func save(_ events: [ActivityEvent]) async throws {
        try await store.save(events)
    }

    public func append(_ event: ActivityEvent) async throws {
        var events = try await load()
        events.append(event)
        try await save(events)
    }

    public func events(for pairID: UUID?) async throws -> [ActivityEvent] {
        let events = try await load().sorted { $0.date > $1.date }
        guard let pairID else {
            return events
        }

        return events.filter { $0.pairID == pairID }
    }
}
