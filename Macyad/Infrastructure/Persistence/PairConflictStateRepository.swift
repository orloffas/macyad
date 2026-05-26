import Foundation

public protocol PairConflictStateStoring: Sendable {
    func load(pairID: UUID) async throws -> PairConflictBaselineState?
    func save(_ state: PairConflictBaselineState) async throws
    func remove(pairID: UUID) async throws
}

public actor PairConflictStateRepository: PairConflictStateStoring {
    private let directoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager

    public init(paths: AppPaths, fileManager: FileManager = .default) {
        self.directoryURL = paths.conflictStateDirectory
        self.fileManager = fileManager
    }

    public func load(pairID: UUID) async throws -> PairConflictBaselineState? {
        let url = fileURL(for: pairID)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(PairConflictBaselineState.self, from: data)
    }

    public func save(_ state: PairConflictBaselineState) async throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(state)
        try data.write(to: fileURL(for: state.pairID), options: .atomic)
    }

    public func remove(pairID: UUID) async throws {
        let url = fileURL(for: pairID)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }

    private func fileURL(for pairID: UUID) -> URL {
        directoryURL.appendingPathComponent("\(pairID.uuidString).json")
    }
}
