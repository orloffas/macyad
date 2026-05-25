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
        ".Spotlight-V100/**",
        ".TemporaryItems/**",
        ".Trashes/**",
        ".fseventsd/**",
        "Thumbs.db",
        "desktop.ini",
        "$RECYCLE.BIN/**",
        "System Volume Information/**",
        "*.tmp",
        "*.temp",
        "*.swp",
        "*.swo",
        "*.part",
        "*.crdownload",
    ]

    public let id: UUID
    public var name: String
    public var localFolderBookmark: Data
    public var localFolderDisplayPath: String
    public var remotePath: String
    public var scheduleMinutes: Int
    public var deletePolicy: DeletePolicy
    public var lastKnownSeverity: Severity
    public var lastSyncAt: Date?
    public var syncExcludes: [String]
    public var checkAdditionalExcludes: [String]

    public init(
        id: UUID,
        name: String,
        localFolderBookmark: Data,
        localFolderDisplayPath: String,
        remotePath: String,
        scheduleMinutes: Int,
        deletePolicy: DeletePolicy,
        lastKnownSeverity: Severity,
        lastSyncAt: Date? = nil,
        syncExcludes: [String] = SyncPair.defaultSyncExcludes,
        checkAdditionalExcludes: [String] = []
    ) {
        self.id = id
        self.name = name
        self.localFolderBookmark = localFolderBookmark
        self.localFolderDisplayPath = localFolderDisplayPath
        self.remotePath = remotePath
        self.scheduleMinutes = scheduleMinutes
        self.deletePolicy = deletePolicy
        self.lastKnownSeverity = lastKnownSeverity
        self.lastSyncAt = lastSyncAt
        self.syncExcludes = syncExcludes
        self.checkAdditionalExcludes = checkAdditionalExcludes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case localFolderBookmark
        case localFolderDisplayPath
        case remotePath
        case scheduleMinutes
        case deletePolicy
        case lastKnownSeverity
        case lastSyncAt
        case syncExcludes
        case checkAdditionalExcludes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        localFolderBookmark = try container.decode(Data.self, forKey: .localFolderBookmark)
        localFolderDisplayPath = try container.decode(String.self, forKey: .localFolderDisplayPath)
        remotePath = try container.decode(String.self, forKey: .remotePath)
        scheduleMinutes = try container.decode(Int.self, forKey: .scheduleMinutes)
        deletePolicy = try container.decode(DeletePolicy.self, forKey: .deletePolicy)
        lastKnownSeverity = try container.decode(Severity.self, forKey: .lastKnownSeverity)
        lastSyncAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncAt)
        syncExcludes = try container.decodeIfPresent([String].self, forKey: .syncExcludes) ?? SyncPair.defaultSyncExcludes
        checkAdditionalExcludes = try container.decodeIfPresent([String].self, forKey: .checkAdditionalExcludes) ?? []
    }

    public var allCheckExcludes: [String] {
        orderedUnique(syncExcludes + checkAdditionalExcludes)
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
