public actor AppPreferencesStore {
    private let store: JSONFileStore<AppPreferences>

    init(store: JSONFileStore<AppPreferences>) {
        self.store = store
    }

    public init(paths: AppPaths) {
        self.store = JSONFileStore(url: paths.preferencesFile)
    }

    public func load() async throws -> AppPreferences {
        try await store.load(default: .defaults)
    }

    public func save(_ preferences: AppPreferences) async throws {
        try await store.save(preferences)
    }
}
