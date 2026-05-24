public actor PairRepository {
    private let store: JSONFileStore<[SyncPair]>

    init(store: JSONFileStore<[SyncPair]>) {
        self.store = store
    }

    public init(paths: AppPaths) {
        self.store = JSONFileStore(url: paths.pairsFile)
    }

    public func load() async throws -> [SyncPair] {
        try await store.load(default: [])
    }

    public func save(_ pairs: [SyncPair]) async throws {
        try await store.save(pairs)
    }
}
