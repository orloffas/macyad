import Foundation

public struct PairService: Sendable {
    public enum ValidationError: Error, Equatable, LocalizedError {
        case emptyName
        case missingLocalFolder
        case emptyRemotePath
        case invalidSchedule

        public var errorDescription: String? {
            switch self {
            case .emptyName:
                "Введите имя пары."
            case .missingLocalFolder:
                "Выберите локальную папку."
            case .emptyRemotePath:
                "Укажите remote path."
            case .invalidSchedule:
                "Интервал синхронизации должен быть больше нуля."
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
        deletePolicy: SyncPair.DeletePolicy
    ) throws -> SyncPair {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localFolderBookmark.isEmpty,
              !localFolderDisplayPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingLocalFolder
        }
        guard !remotePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyRemotePath
        }
        guard scheduleMinutes > 0 else {
            throw ValidationError.invalidSchedule
        }

        return SyncPair(
            id: UUID(),
            name: name,
            localFolderBookmark: localFolderBookmark,
            localFolderDisplayPath: localFolderDisplayPath,
            remotePath: remotePath,
            scheduleMinutes: scheduleMinutes,
            deletePolicy: deletePolicy,
            lastKnownSeverity: .healthy
        )
    }
}
