actor PairRepository {
    private let store: JSONFileStore<[SyncPair]>

    init(store: JSONFileStore<[SyncPair]>) {
        self.store = store
    }

    func load() async throws -> [SyncPair] {
        try await store.load(default: [])
    }

    func save(_ pairs: [SyncPair]) async throws {
        try await store.save(pairs)
    }
}
