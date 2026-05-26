import Foundation

public protocol PairSnapshotProviding: Sendable {
    func snapshot(for pair: SyncPair, path: String, mode: RcloneExcludeFileMode) async throws -> PairSnapshot
}

public struct RcloneSnapshotProvider: PairSnapshotProviding, Sendable {
    private struct ListingEntry: Decodable {
        let path: String
        let size: Int64
        let modTime: Date?
        let hashes: [String: String]?

        enum CodingKeys: String, CodingKey {
            case path = "Path"
            case size = "Size"
            case modTime = "ModTime"
            case hashes = "Hashes"
        }
    }

    private let processClient: RcloneProcessRunning
    private let configPath: String?
    private let excludeFileStore: RcloneExcludeFilePreparing?
    private let decoder = JSONDecoder()

    public init(
        processClient: RcloneProcessRunning,
        configPath: String? = nil,
        excludeFileStore: RcloneExcludeFilePreparing? = nil
    ) {
        self.processClient = processClient
        self.configPath = configPath
        self.excludeFileStore = excludeFileStore
        decoder.dateDecodingStrategy = .iso8601
    }

    public func snapshot(for pair: SyncPair, path: String, mode: RcloneExcludeFileMode) async throws -> PairSnapshot {
        let excludeFilePath = try excludeFileStore?.prepareExcludeFile(for: pair, mode: mode)
        let arguments = RcloneCommandBuilder.lsjsonArguments(path: path, configPath: configPath, excludeFilePath: excludeFilePath)
        let result = try await processClient.run(arguments)

        guard result.exitCode == 0 else {
            throw SyncService.CommandFailedError(
                command: arguments,
                exitCode: result.exitCode,
                stdout: result.stdout,
                stderr: result.stderr
            )
        }

        let entries = try decoder.decode([ListingEntry].self, from: Data(result.stdout.utf8))
        return PairSnapshot(entries: entries.map {
            PairSnapshotEntry(path: $0.path, size: $0.size, modTime: $0.modTime, md5: $0.hashes?["MD5"])
        })
    }
}
