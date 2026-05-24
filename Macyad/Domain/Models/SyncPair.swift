import Foundation

public struct SyncPair: Codable, Equatable, Identifiable, Sendable {
    public enum DeletePolicy: String, Codable, Sendable {
        case mirrorToYandex
        case keepRemoteDeletesManual
    }

    public let id: UUID
    public var name: String
    public var localFolderBookmark: Data
    public var localFolderDisplayPath: String
    public var remotePath: String
    public var scheduleMinutes: Int
    public var deletePolicy: DeletePolicy
    public var lastKnownSeverity: Severity
    public var lastSyncAt: Date?

    public init(
        id: UUID,
        name: String,
        localFolderBookmark: Data,
        localFolderDisplayPath: String,
        remotePath: String,
        scheduleMinutes: Int,
        deletePolicy: DeletePolicy,
        lastKnownSeverity: Severity,
        lastSyncAt: Date? = nil
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
    }
}
