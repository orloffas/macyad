import Combine
import Foundation

@MainActor
public protocol FolderPicking {
    func pickFolder() -> (bookmark: Data, displayPath: String)?
}

@MainActor
public final class CreatePairViewModel: ObservableObject {
    @Published public var name = ""
    @Published public var localFolderBookmark = Data()
    @Published public var localFolderDisplayPath: String?
    @Published public var remotePath = "yd:/"
    @Published public var scheduleMinutes = 30
    @Published public var deletePolicy: SyncPair.DeletePolicy = .mirrorToYandex

    private let folderPicker: FolderPicking
    private let pairService: PairService

    public var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        localFolderDisplayPath != nil &&
        !remotePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        folderPicker: FolderPicking,
        pairService: PairService,
        defaultScheduleMinutes: Int = AppPreferences.defaults.defaultScheduleMinutes
    ) {
        self.folderPicker = folderPicker
        self.pairService = pairService
        self.scheduleMinutes = defaultScheduleMinutes
    }

    public func chooseFolder() {
        guard let result = folderPicker.pickFolder() else {
            return
        }

        localFolderBookmark = result.bookmark
        localFolderDisplayPath = result.displayPath
    }

    public func buildPair() throws -> SyncPair {
        try pairService.makePair(
            name: name,
            localFolderBookmark: localFolderBookmark,
            localFolderDisplayPath: localFolderDisplayPath ?? "",
            remotePath: remotePath,
            scheduleMinutes: scheduleMinutes,
            deletePolicy: deletePolicy
        )
    }
}
