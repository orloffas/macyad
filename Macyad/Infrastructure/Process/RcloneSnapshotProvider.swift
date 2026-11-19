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
        // rclone silently ignores one of two folders that differ only in Unicode normalization;
        // stop here with an explanation instead of syncing into the wrong one.
        let duplicates = RcloneErrorExplainer.normalizationDuplicates(in: entries.map(\.path))
        if !duplicates.isEmpty {
            throw SyncService.CommandFailedError(
                command: arguments,
                exitCode: 1,
                stderr: RcloneErrorExplainer.duplicateStderr(for: duplicates)
            )
        }
        return PairSnapshot(entries: entries.map {
            // rclone names hashes in lower case ("md5"); the old "MD5" lookup never matched,
            // so no snapshot ever carried a hash and every mtime change looked like an edit.
            PairSnapshotEntry(path: $0.path, size: $0.size, modTime: $0.modTime,
                              md5: $0.hashes?.first { $0.key.lowercased() == "md5" }?.value)
        })
    }
}
