import Foundation

/// Portable snapshot of what the user configured: pairs, accounts and
/// preferences. Deliberately not a backup of the app's state directory —
/// see `ConfigurationTransferService` for what is stripped and why.
public struct ConfigurationExport: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var preferences: AppPreferences
    public var accounts: [YandexAccount]
    public var pairs: [SyncPair]

    public init(
        schemaVersion: Int = ConfigurationExport.currentSchemaVersion,
        exportedAt: Date,
        preferences: AppPreferences,
        accounts: [YandexAccount],
        pairs: [SyncPair]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.preferences = preferences
        self.accounts = accounts
        self.pairs = pairs
    }
}

/// Something the import could not carry over to this machine. The pair is
/// still imported — switched off — so the user can fix it in place instead of
/// losing the configuration.
public struct ConfigurationImportIssue: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// The folder the pair syncs does not exist here.
        case missingLocalFolder(path: String)
        /// This machine's rclone.conf has no remote under that name.
        case missingRemote(name: String)
    }

    public let pairName: String
    public let kind: Kind

    public init(pairName: String, kind: Kind) {
        self.pairName = pairName
        self.kind = kind
    }
}

/// What a confirmed import will write, plus everything that needs saying
/// about it. Produced before anything is persisted so the UI can ask first.
public struct ConfigurationImportPlan: Equatable, Sendable {
    public let preferences: AppPreferences
    public let accounts: [YandexAccount]
    public let pairs: [SyncPair]
    public let issues: [ConfigurationImportIssue]

    public init(
        preferences: AppPreferences,
        accounts: [YandexAccount],
        pairs: [SyncPair],
        issues: [ConfigurationImportIssue]
    ) {
        self.preferences = preferences
        self.accounts = accounts
        self.pairs = pairs
        self.issues = issues
    }
}
