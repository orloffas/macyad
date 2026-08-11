import Foundation

public struct ConfigurationTransferService: Sendable {
    public enum ImportError: LocalizedError, Equatable {
        case unsupportedSchema(found: Int, supported: Int)

        public var errorDescription: String? {
            switch self {
            case let .unsupportedSchema(found, supported):
                AppCopy.current.configurationImportUnsupportedSchema(found: found, supported: supported)
            }
        }
    }

    public init() {}

    /// Reads the file, checking the version before anything else. Decoding the
    /// whole document first would turn "this file is from a newer MacYaD" into
    /// a generic decoding error, because a future version is free to change
    /// the shape of what it nests.
    public func decodeExport(from data: Data) throws -> ConfigurationExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope = try decoder.decode(ConfigurationExportEnvelope.self, from: data)
        try validate(schemaVersion: envelope.schemaVersion)

        return try decoder.decode(ConfigurationExport.self, from: data)
    }

    public func encode(_ export: ConfigurationExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(export)
    }

    private func validate(schemaVersion: Int) throws {
        guard schemaVersion <= ConfigurationExport.currentSchemaVersion else {
            throw ImportError.unsupportedSchema(
                found: schemaVersion,
                supported: ConfigurationExport.currentSchemaVersion
            )
        }
    }

    /// Strips everything that cannot travel: security-scoped bookmarks are
    /// tied to this Mac and its TCC grants, and the sync timestamps and
    /// severity describe runs that happened here. Credentials never appear —
    /// they live in rclone.conf, which this file does not touch.
    public func makeExport(
        preferences: AppPreferences,
        accounts: [YandexAccount],
        pairs: [SyncPair],
        at date: Date = Date()
    ) -> ConfigurationExport {
        ConfigurationExport(
            exportedAt: date,
            preferences: preferences,
            accounts: accounts,
            pairs: pairs.map { pair in
                var exported = pair
                exported.localFolderBookmark = Data()
                exported.lastSyncAt = nil
                exported.lastScheduledSyncAttemptAt = nil
                exported.lastKnownSeverity = .healthy
                return exported
            }
        )
    }

    /// Works out what importing this file would produce, without writing
    /// anything. Every pair arrives with scheduling off: on a machine whose
    /// local folder is empty or missing, a scheduled push with the mirror
    /// delete policy would read that as "everything was deleted" and clear the
    /// remote. The user turns pairs back on once a check says the two sides
    /// agree.
    ///
    /// - Parameters:
    ///   - configPath: this machine's rclone.conf, which replaces the exported
    ///     path — the file may well come from a Mac with a different home.
    ///   - availableRemoteNames: remotes configured here, used to flag pairs
    ///     whose remote is missing.
    ///   - folderExists: whether the pair's local folder is present here.
    ///   - bookmarkForPath: makes a fresh bookmark for a folder that exists;
    ///     returns nil when one cannot be made.
    public func prepareImport(
        _ export: ConfigurationExport,
        configPath: String,
        availableRemoteNames: [String],
        folderExists: (String) -> Bool,
        bookmarkForPath: (String) -> Data?
    ) throws -> ConfigurationImportPlan {
        try validate(schemaVersion: export.schemaVersion)

        // A hand-edited or truncated file can repeat an id. Two pairs sharing
        // one id break SwiftUI's Identifiable lists and make "which pair did I
        // just edit" unanswerable, so later duplicates are dropped.
        var seenAccountIDs: Set<UUID> = []
        let accounts = export.accounts.compactMap { account -> YandexAccount? in
            guard seenAccountIDs.insert(account.id).inserted else {
                return nil
            }

            var imported = account
            imported.configPath = configPath
            return imported
        }

        var issues: [ConfigurationImportIssue] = []
        var seenPairIDs: Set<UUID> = []
        let pairs = export.pairs.compactMap { pair -> SyncPair? in
            guard seenPairIDs.insert(pair.id).inserted else {
                return nil
            }

            return pair
        }.map { pair -> SyncPair in
            var imported = pair
            imported.autoSyncMode = .off
            imported.lastSyncAt = nil
            imported.lastScheduledSyncAttemptAt = nil
            imported.lastKnownSeverity = .healthy
            imported.localFolderBookmark = Data()

            if folderExists(pair.localFolderDisplayPath) {
                imported.localFolderBookmark = bookmarkForPath(pair.localFolderDisplayPath) ?? Data()
            }

            if imported.localFolderBookmark.isEmpty {
                issues.append(
                    ConfigurationImportIssue(
                        pairName: pair.name,
                        kind: .unusableLocalFolder(path: pair.localFolderDisplayPath)
                    )
                )
            }

            if let remoteName = pair.parsedRemoteName, !availableRemoteNames.contains(remoteName) {
                issues.append(
                    ConfigurationImportIssue(pairName: pair.name, kind: .missingRemote(name: remoteName))
                )
            }

            if !accounts.contains(where: { $0.id == pair.accountID }) {
                issues.append(ConfigurationImportIssue(pairName: pair.name, kind: .missingAccount))
            }

            return imported
        }

        var preferences = export.preferences
        // The imported file may say schedules were running; they were running
        // somewhere else, against folders this Mac has not verified yet.
        preferences.isGlobalSchedulerPaused = true

        return ConfigurationImportPlan(
            preferences: preferences,
            accounts: accounts,
            pairs: pairs,
            issues: issues
        )
    }
}
