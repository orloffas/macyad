actor AppPreferencesStore {
    private let store: JSONFileStore<AppPreferences>

    init(store: JSONFileStore<AppPreferences>) {
        self.store = store
    }

    func load() async throws -> AppPreferences {
        try await store.load(default: .defaults)
    }

    func save(_ preferences: AppPreferences) async throws {
        try await store.save(preferences)
    }
}
