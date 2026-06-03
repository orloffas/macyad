import Foundation

public struct SyncPair: Codable, Equatable, Identifiable, Sendable {
    public enum DeletePolicy: String, Codable, Sendable {
        case mirrorToYandex
        case keepRemoteDeletesManual
    }

    public static let defaultSyncExcludes: [String] = [
        ".DS_Store",
        ".localized",
        "._*",
        ".AppleDouble",
        "__MACOSX/**",
        ".DocumentRevisions-V100/**",
        ".Spotlight-V100/**",
        ".TemporaryItems/**",
        ".Trashes/**",
        ".fseventsd/**",
        ".VolumeIcon.icns",
        ".com.apple.timemachine.donotpresent",
        ".com.apple.timemachine.supported",
        "Icon?",
        "Thumbs.db",
        "desktop.ini",
        "$RECYCLE.BIN/**",
        "System Volume Information/**",
        ".git/**",
        ".hg/**",
        ".svn/**",
        ".jj/**",
        "CVS/**",
        ".venv/**",
        "venv/**",
        "env/**",
        "ENV/**",
        "env.bak/**",
        "venv.bak/**",
        "__pycache__/**",
        "*.pyc",
        "*.pyo",
        "*.pyd",
        ".pytest_cache/**",
        ".mypy_cache/**",
        ".ruff_cache/**",
        ".pyre/**",
        ".pytype/**",
        ".tox/**",
        ".nox/**",
        ".hypothesis/**",
        ".ipynb_checkpoints/**",
        ".pixi/**",
        "__pypackages__/**",
        "*.tmp",
        "*.temp",
        "*.swp",
        "*.swo",
        "*.part",
        "*.crdownload",
    ]

    public static let unassignedAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    public let id: UUID
    public var name: String
    public var localFolderBookmark: Data
    public var localFolderDisplayPath: String
    public var remotePath: String
    public var accountID: UUID
    public var conflictPolicy: ConflictPolicy
    public var scheduleMinutes: Int
    public var deletePolicy: DeletePolicy
    public var lastKnownSeverity: Severity
    public var lastSyncAt: Date?
    public var lastScheduledPushAttemptAt: Date?
    public var syncExcludes: [String]
    public var checkAdditionalExcludes: [String]
    public var isAutoPushEnabled: Bool

    public init(
        id: UUID,
        name: String,
        localFolderBookmark: Data,
        localFolderDisplayPath: String,
        remotePath: String,
        accountID: UUID = SyncPair.unassignedAccountID,
        conflictPolicy: ConflictPolicy = .block,
        scheduleMinutes: Int,
        deletePolicy: DeletePolicy,
        lastKnownSeverity: Severity,
        lastSyncAt: Date? = nil,
        lastScheduledPushAttemptAt: Date? = nil,
        syncExcludes: [String] = SyncPair.defaultSyncExcludes,
        checkAdditionalExcludes: [String] = [],
        isAutoPushEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.localFolderBookmark = localFolderBookmark
        self.localFolderDisplayPath = localFolderDisplayPath
        self.remotePath = remotePath
        self.accountID = accountID
        self.conflictPolicy = conflictPolicy
        self.scheduleMinutes = scheduleMinutes
        self.deletePolicy = deletePolicy
        self.lastKnownSeverity = lastKnownSeverity
        self.lastSyncAt = lastSyncAt
        self.lastScheduledPushAttemptAt = lastScheduledPushAttemptAt
        self.syncExcludes = syncExcludes
        self.checkAdditionalExcludes = checkAdditionalExcludes
        self.isAutoPushEnabled = isAutoPushEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case localFolderBookmark
        case localFolderDisplayPath
        case remotePath
        case accountID
        case conflictPolicy
        case scheduleMinutes
        case deletePolicy
        case lastKnownSeverity
        case lastSyncAt
        case lastScheduledPushAttemptAt
        case syncExcludes
        case checkAdditionalExcludes
        case isAutoPushEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        localFolderBookmark = try container.decode(Data.self, forKey: .localFolderBookmark)
        localFolderDisplayPath = try container.decode(String.self, forKey: .localFolderDisplayPath)
        remotePath = try container.decode(String.self, forKey: .remotePath)
        accountID = try container.decodeIfPresent(UUID.self, forKey: .accountID) ?? SyncPair.unassignedAccountID
        conflictPolicy = try container.decodeIfPresent(ConflictPolicy.self, forKey: .conflictPolicy) ?? .block
        scheduleMinutes = try container.decode(Int.self, forKey: .scheduleMinutes)
        deletePolicy = try container.decode(DeletePolicy.self, forKey: .deletePolicy)
        lastKnownSeverity = try container.decode(Severity.self, forKey: .lastKnownSeverity)
        lastSyncAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncAt)
        lastScheduledPushAttemptAt = try container.decodeIfPresent(Date.self, forKey: .lastScheduledPushAttemptAt)
        syncExcludes = try container.decodeIfPresent([String].self, forKey: .syncExcludes) ?? SyncPair.defaultSyncExcludes
        checkAdditionalExcludes = try container.decodeIfPresent([String].self, forKey: .checkAdditionalExcludes) ?? []
        isAutoPushEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutoPushEnabled) ?? true
    }

    public var allCheckExcludes: [String] {
        orderedUnique(syncExcludes + checkAdditionalExcludes)
    }

    public var nextScheduledReferenceAt: Date? {
        [lastSyncAt, lastScheduledPushAttemptAt].compactMap { $0 }.max()
    }

    public var hasAssignedAccount: Bool {
        accountID != Self.unassignedAccountID
    }

    public var parsedRemoteName: String? {
        Self.remoteName(from: remotePath)
    }

    public var parsedRemoteSubpath: String {
        Self.remoteSubpath(from: remotePath)
    }

    public static func remoteName(from remotePath: String) -> String? {
        let trimmed = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = trimmed.firstIndex(of: ":"), separatorIndex > trimmed.startIndex else {
            return nil
        }

        return String(trimmed[..<separatorIndex])
    }

    public static func remoteSubpath(from remotePath: String) -> String {
        let trimmed = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = trimmed.firstIndex(of: ":") else {
            return trimmed
        }

        let suffix = trimmed[trimmed.index(after: separatorIndex)...]
        return String(suffix).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    public static func composeRemotePath(remoteName: String, remoteSubpath: String) -> String {
        let trimmedRemoteName = remoteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubpath = remoteSubpath.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !trimmedSubpath.isEmpty else {
            return "\(trimmedRemoteName):/"
        }

        return "\(trimmedRemoteName):/\(trimmedSubpath)"
    }

    private func orderedUnique(_ patterns: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for pattern in patterns.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !pattern.isEmpty {
            if seen.insert(pattern).inserted {
                result.append(pattern)
            }
        }

        return result
    }
}
