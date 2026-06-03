import Combine
import Foundation

@MainActor
public protocol FolderPicking {
    func pickFolder() -> (bookmark: Data, displayPath: String)?
}

@MainActor
public final class CreatePairViewModel: ObservableObject {
    private let existingPair: SyncPair?
    @Published public private(set) var availableAccounts: [YandexAccount]
    @Published public var name = ""
    @Published public var localFolderBookmark = Data()
    @Published public var localFolderDisplayPath: String?
    @Published public var selectedAccountID = SyncPair.unassignedAccountID
    @Published public var remoteSubpath = ""
    @Published public var conflictPolicy: ConflictPolicy = .block
    @Published public var scheduleMinutes: Int = 30 {
        didSet {
            let clamped = scheduleMinutes.clamped(to: 1...1440)
            if scheduleMinutes != clamped { scheduleMinutes = clamped }
        }
    }
    @Published public var intervalInputText: String = "30"
    @Published public var deletePolicy: SyncPair.DeletePolicy = .mirrorToYandex
    @Published public var syncExcludesText = SyncPair.defaultSyncExcludes.joined(separator: "\n")
    @Published public var checkAdditionalExcludesText = ""

    private let folderPicker: FolderPicking
    private let pairService: PairService

    public var isEditing: Bool {
        existingPair != nil
    }

    public var isIntervalValid: Bool {
        guard let value = Int(intervalInputText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return (1...1440).contains(value)
    }

    public var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        localFolderDisplayPath != nil &&
        selectedAccountID != SyncPair.unassignedAccountID &&
        !resolvedRemotePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isIntervalValid
    }

    public init(
        existingPair: SyncPair? = nil,
        accounts: [YandexAccount],
        folderPicker: FolderPicking,
        pairService: PairService,
        defaultScheduleMinutes: Int = AppPreferences.defaults.defaultScheduleMinutes
    ) {
        self.existingPair = existingPair
        self.availableAccounts = Self.sortAccounts(accounts)
        self.folderPicker = folderPicker
        self.pairService = pairService
        self.name = existingPair?.name ?? ""
        self.localFolderBookmark = existingPair?.localFolderBookmark ?? Data()
        self.localFolderDisplayPath = existingPair?.localFolderDisplayPath
        self.selectedAccountID = existingPair?.accountID ?? self.availableAccounts.first?.id ?? SyncPair.unassignedAccountID
        self.remoteSubpath = existingPair.map(\.parsedRemoteSubpath) ?? ""
        self.conflictPolicy = existingPair?.conflictPolicy ?? .block
        let minutes = existingPair?.scheduleMinutes ?? defaultScheduleMinutes
        self.scheduleMinutes = minutes.clamped(to: 1...1440)
        self.intervalInputText = "\(self.scheduleMinutes)"
        self.deletePolicy = existingPair?.deletePolicy ?? .mirrorToYandex
        self.syncExcludesText = Self.makeExcludeText(from: existingPair?.syncExcludes ?? SyncPair.defaultSyncExcludes)
        self.checkAdditionalExcludesText = Self.makeExcludeText(from: existingPair?.checkAdditionalExcludes ?? [])
    }

    public func commitIntervalText() {
        guard let value = Int(intervalInputText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...1440).contains(value) else { return }
        scheduleMinutes = value
    }

    public func replaceAvailableAccounts(_ accounts: [YandexAccount]) {
        let sortedAccounts = Self.sortAccounts(accounts)
        availableAccounts = sortedAccounts

        guard sortedAccounts.contains(where: { $0.id == selectedAccountID }) else {
            if let existingPair,
               sortedAccounts.contains(where: { $0.id == existingPair.accountID }) {
                selectedAccountID = existingPair.accountID
            } else {
                selectedAccountID = sortedAccounts.first?.id ?? SyncPair.unassignedAccountID
            }
            return
        }
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
        let resolvedRemotePath = self.resolvedRemotePath

        if let existingPair {
            return try pairService.updatePair(
                existingPair,
                name: name,
                localFolderBookmark: localFolderBookmark,
                localFolderDisplayPath: localFolderDisplayPath ?? "",
                remotePath: resolvedRemotePath,
                accountID: selectedAccountID,
                conflictPolicy: conflictPolicy,
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
            remotePath: resolvedRemotePath,
            accountID: selectedAccountID,
            conflictPolicy: conflictPolicy,
            scheduleMinutes: scheduleMinutes,
            deletePolicy: deletePolicy,
            syncExcludes: syncExcludes,
            checkAdditionalExcludes: checkAdditionalExcludes
        )
    }

    public var resolvedRemotePath: String {
        guard let account = availableAccounts.first(where: { $0.id == selectedAccountID }) else {
            return ""
        }

        return SyncPair.composeRemotePath(remoteName: account.remoteName, remoteSubpath: remoteSubpath)
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

    private static func sortAccounts(_ accounts: [YandexAccount]) -> [YandexAccount] {
        accounts.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
