import Foundation

actor JSONFileStore<Value: Codable & Sendable> {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL) {
        self.url = url
    }

    func load(default defaultValue: Value) throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return defaultValue
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(Value.self, from: data)
    }

    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
