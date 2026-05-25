import Combine
import Foundation

@MainActor
public protocol FolderPicking {
    func pickFolder() -> (bookmark: Data, displayPath: String)?
}

@MainActor
public final class CreatePairViewModel: ObservableObject {
    private let existingPair: SyncPair?
    @Published public var name = ""
    @Published public var localFolderBookmark = Data()
    @Published public var localFolderDisplayPath: String?
    @Published public var remotePath = "yd:/"
    @Published public var scheduleMinutes = 30
    @Published public var deletePolicy: SyncPair.DeletePolicy = .mirrorToYandex
    @Published public var syncExcludesText = SyncPair.defaultSyncExcludes.joined(separator: "\n")
    @Published public var checkAdditionalExcludesText = ""

    private let folderPicker: FolderPicking
    private let pairService: PairService

    public var isEditing: Bool {
        existingPair != nil
    }

    public var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        localFolderDisplayPath != nil &&
        !remotePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        existingPair: SyncPair? = nil,
        folderPicker: FolderPicking,
        pairService: PairService,
        defaultScheduleMinutes: Int = AppPreferences.defaults.defaultScheduleMinutes
    ) {
        self.existingPair = existingPair
        self.folderPicker = folderPicker
        self.pairService = pairService
        self.name = existingPair?.name ?? ""
        self.localFolderBookmark = existingPair?.localFolderBookmark ?? Data()
        self.localFolderDisplayPath = existingPair?.localFolderDisplayPath
        self.remotePath = existingPair?.remotePath ?? "yd:/"
        self.scheduleMinutes = existingPair?.scheduleMinutes ?? defaultScheduleMinutes
        self.deletePolicy = existingPair?.deletePolicy ?? .mirrorToYandex
        self.syncExcludesText = Self.makeExcludeText(from: existingPair?.syncExcludes ?? SyncPair.defaultSyncExcludes)
        self.checkAdditionalExcludesText = Self.makeExcludeText(from: existingPair?.checkAdditionalExcludes ?? [])
    }

    public func chooseFolder() {
        guard let result = folderPicker.pickFolder() else {
            return
        }

        localFolderBookmark = result.bookmark
        localFolderDisplayPath = result.displayPath
    }

    public func buildPair() throws -> SyncPair {
        let syncExcludes = parseExcludeText(syncExcludesText)
        let checkAdditionalExcludes = parseExcludeText(checkAdditionalExcludesText)

        if let existingPair {
            return try pairService.updatePair(
                existingPair,
                name: name,
                localFolderBookmark: localFolderBookmark,
                localFolderDisplayPath: localFolderDisplayPath ?? "",
                remotePath: remotePath,
                scheduleMinutes: scheduleMinutes,
                deletePolicy: deletePolicy,
                syncExcludes: syncExcludes,
                checkAdditionalExcludes: checkAdditionalExcludes
            )
        }

        return try pairService.makePair(
            name: name,
            localFolderBookmark: localFolderBookmark,
            localFolderDisplayPath: localFolderDisplayPath ?? "",
            remotePath: remotePath,
            scheduleMinutes: scheduleMinutes,
            deletePolicy: deletePolicy,
            syncExcludes: syncExcludes,
            checkAdditionalExcludes: checkAdditionalExcludes
        )
    }

    private func parseExcludeText(_ text: String) -> [String] {
        var seen = Set<String>()

        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    private static func makeExcludeText(from patterns: [String]) -> String {
        patterns.joined(separator: "\n")
    }
}
