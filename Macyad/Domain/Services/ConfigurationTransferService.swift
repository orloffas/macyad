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
        guard export.schemaVersion <= ConfigurationExport.currentSchemaVersion else {
            throw ImportError.unsupportedSchema(
                found: export.schemaVersion,
                supported: ConfigurationExport.currentSchemaVersion
            )
        }

        let accounts = export.accounts.map { account -> YandexAccount in
            var imported = account
            imported.configPath = configPath
            return imported
        }

        var issues: [ConfigurationImportIssue] = []
        let pairs = export.pairs.map { pair -> SyncPair in
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
                        kind: .missingLocalFolder(path: pair.localFolderDisplayPath)
                    )
                )
            }

            if let remoteName = pair.parsedRemoteName, !availableRemoteNames.contains(remoteName) {
                issues.append(
                    ConfigurationImportIssue(pairName: pair.name, kind: .missingRemote(name: remoteName))
                )
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
