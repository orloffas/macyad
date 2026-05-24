import Foundation

struct SyncPair: Codable, Equatable, Identifiable, Sendable {
    enum DeletePolicy: String, Codable, Sendable {
        case mirrorToYandex
        case keepRemoteDeletesManual
    }

    let id: UUID
    var name: String
    var localFolderBookmark: Data
    var localFolderDisplayPath: String
    var remotePath: String
    var scheduleMinutes: Int
    var deletePolicy: DeletePolicy
    var lastKnownSeverity: Severity
}
