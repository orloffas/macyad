import Foundation

public actor AccountRepository {
    private let store: JSONFileStore<[YandexAccount]>

    init(store: JSONFileStore<[YandexAccount]>) {
        self.store = store
    }

    public init(paths: AppPaths) {
        self.store = JSONFileStore(url: paths.accountsFile)
    }

    public func load() async throws -> [YandexAccount] {
        try await store.load(default: [])
    }

    public func save(_ accounts: [YandexAccount]) async throws {
        try await store.save(accounts.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending })
    }
}
