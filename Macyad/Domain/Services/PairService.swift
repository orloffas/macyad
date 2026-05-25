import Foundation

public struct PairService: Sendable {
    public enum ValidationError: Error, Equatable, LocalizedError {
        case emptyName
        case missingLocalFolder
        case emptyRemotePath
        case invalidSchedule

        public var errorDescription: String? {
            let copy = AppCopy.current

            return switch self {
            case .emptyName:
                copy.pairValidationEmptyName
            case .missingLocalFolder:
                copy.pairValidationMissingLocalFolder
            case .emptyRemotePath:
                copy.pairValidationEmptyRemotePath
            case .invalidSchedule:
                copy.pairValidationInvalidSchedule
            }
        }
    }

    public init() {}

    public func makePair(
        name: String,
        localFolderBookmark: Data,
        localFolderDisplayPath: String,
        remotePath: String,
        scheduleMinutes: Int,
        deletePolicy: SyncPair.DeletePolicy,
        syncExcludes: [String] = SyncPair.defaultSyncExcludes,
        checkAdditionalExcludes: [String] = []
    ) throws -> SyncPair {
        let fields = try validate(
            name: name,
            localFolderBookmark: localFolderBookmark,
            localFolderDisplayPath: localFolderDisplayPath,
            remotePath: remotePath,
            scheduleMinutes: scheduleMinutes
        )

        return SyncPair(
            id: UUID(),
            name: fields.name,
            localFolderBookmark: fields.localFolderBookmark,
            localFolderDisplayPath: fields.localFolderDisplayPath,
            remotePath: fields.remotePath,
            scheduleMinutes: fields.scheduleMinutes,
            deletePolicy: deletePolicy,
            lastKnownSeverity: .healthy,
            syncExcludes: syncExcludes,
            checkAdditionalExcludes: checkAdditionalExcludes
        )
    }

    public func updatePair(
        _ existingPair: SyncPair,
        name: String,
        localFolderBookmark: Data,
        localFolderDisplayPath: String,
        remotePath: String,
        scheduleMinutes: Int,
        deletePolicy: SyncPair.DeletePolicy,
        syncExcludes: [String],
        checkAdditionalExcludes: [String]
    ) throws -> SyncPair {
        let fields = try validate(
            name: name,
            localFolderBookmark: localFolderBookmark,
            localFolderDisplayPath: localFolderDisplayPath,
            remotePath: remotePath,
            scheduleMinutes: scheduleMinutes
        )

        return SyncPair(
            id: existingPair.id,
            name: fields.name,
            localFolderBookmark: fields.localFolderBookmark,
            localFolderDisplayPath: fields.localFolderDisplayPath,
            remotePath: fields.remotePath,
            scheduleMinutes: fields.scheduleMinutes,
            deletePolicy: deletePolicy,
            lastKnownSeverity: existingPair.lastKnownSeverity,
            lastSyncAt: existingPair.lastSyncAt,
            syncExcludes: syncExcludes,
            checkAdditionalExcludes: checkAdditionalExcludes
        )
    }

    private func validate(
        name: String,
        localFolderBookmark: Data,
        localFolderDisplayPath: String,
        remotePath: String,
        scheduleMinutes: Int
    ) throws -> (
        name: String,
        localFolderBookmark: Data,
        localFolderDisplayPath: String,
        remotePath: String,
        scheduleMinutes: Int
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocalFolderPath = localFolderDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRemotePath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localFolderBookmark.isEmpty, !trimmedLocalFolderPath.isEmpty else {
            throw ValidationError.missingLocalFolder
        }
        guard !trimmedRemotePath.isEmpty else {
            throw ValidationError.emptyRemotePath
        }
        guard scheduleMinutes > 0 else {
            throw ValidationError.invalidSchedule
        }

        return (
            name: trimmedName,
            localFolderBookmark: localFolderBookmark,
            localFolderDisplayPath: trimmedLocalFolderPath,
            remotePath: trimmedRemotePath,
            scheduleMinutes: scheduleMinutes
        )
    }
}
