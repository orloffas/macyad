actor ActivityRepository {
    private let store: JSONFileStore<[ActivityEvent]>

    init(store: JSONFileStore<[ActivityEvent]>) {
        self.store = store
    }

    func load() async throws -> [ActivityEvent] {
        try await store.load(default: [])
    }

    func save(_ events: [ActivityEvent]) async throws {
        try await store.save(events)
    }
}
