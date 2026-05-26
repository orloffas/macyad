import Foundation

public struct AccountService: Sendable {
    public enum ValidationError: Error, Equatable, LocalizedError {
        case emptyDisplayName
        case emptyRemoteName
        case duplicateRemoteName
        case accountInUse

        public var errorDescription: String? {
            let copy = AppCopy.current

            return switch self {
            case .emptyDisplayName:
                copy.accountValidationEmptyDisplayName
            case .emptyRemoteName:
                copy.accountValidationEmptyRemoteName
            case .duplicateRemoteName:
                copy.accountValidationDuplicateRemoteName
            case .accountInUse:
                copy.accountValidationInUse
            }
        }
    }

    public init() {}

    public func makeAccount(
        displayName: String,
        remoteName: String,
        configPath: String,
        existingAccounts: [YandexAccount],
        isManaged: Bool = true,
        remoteRootHint: String? = nil,
        now: Date = Date()
    ) throws -> YandexAccount {
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRemoteName = Self.normalizeRemoteName(remoteName)

        guard !normalizedDisplayName.isEmpty else {
            throw ValidationError.emptyDisplayName
        }

        guard !normalizedRemoteName.isEmpty else {
            throw ValidationError.emptyRemoteName
        }

        guard !existingAccounts.contains(where: { $0.remoteName.caseInsensitiveCompare(normalizedRemoteName) == .orderedSame }) else {
            throw ValidationError.duplicateRemoteName
        }

        return YandexAccount(
            id: UUID(),
            displayName: normalizedDisplayName,
            remoteName: normalizedRemoteName,
            configPath: configPath,
            isManaged: isManaged,
            remoteRootHint: remoteRootHint,
            createdAt: now
        )
    }

    public func removeAccount(
        _ account: YandexAccount,
        from accounts: [YandexAccount],
        pairs: [SyncPair]
    ) throws -> [YandexAccount] {
        guard !pairs.contains(where: { $0.accountID == account.id }) else {
            throw ValidationError.accountInUse
        }

        return accounts.filter { $0.id != account.id }
    }

    public func removalState(
        for account: YandexAccount,
        pairs: [SyncPair],
        copy: AppCopy = .current
    ) -> AccountRemovalState {
        let blockingPairNames = pairs
            .filter { $0.accountID == account.id }
            .map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        guard !blockingPairNames.isEmpty else {
            return AccountRemovalState(
                canRemove: true,
                blockingPairNames: [],
                inlineMessage: nil
            )
        }

        return AccountRemovalState(
            canRemove: false,
            blockingPairNames: blockingPairNames,
            inlineMessage: copy.accountRemovalBlockedMessage(pairNames: blockingPairNames)
        )
    }

    public func reconcileAccounts(
        storedAccounts: [YandexAccount],
        pairs: [SyncPair],
        configPath: String,
        configRemoteNames: [String]
    ) -> (accounts: [YandexAccount], pairs: [SyncPair], didMutate: Bool) {
        var didMutate = false
        var accounts = storedAccounts
        let knownRemoteNames = Set(
            storedAccounts.map { $0.remoteName.lowercased() } +
            configRemoteNames.map { Self.normalizeRemoteName($0).lowercased() } +
            pairs.compactMap { $0.parsedRemoteName?.lowercased() }
        )

        for remoteName in knownRemoteNames.sorted() {
            guard !remoteName.isEmpty else {
                continue
            }

            if accounts.contains(where: { $0.remoteName.lowercased() == remoteName }) {
                continue
            }

            accounts.append(
                YandexAccount(
                    id: UUID(),
                    displayName: remoteName,
                    remoteName: remoteName,
                    configPath: configPath,
                    isManaged: false
                )
            )
            didMutate = true
        }

        var pairsNeedingUpdate: [SyncPair] = []
        for pair in pairs {
            guard !pair.hasAssignedAccount || !accounts.contains(where: { $0.id == pair.accountID }) else {
                continue
            }

            guard let remoteName = pair.parsedRemoteName,
                  let matchingAccount = accounts.first(where: { $0.remoteName.caseInsensitiveCompare(remoteName) == .orderedSame }) else {
                continue
            }

            var updatedPair = pair
            updatedPair.accountID = matchingAccount.id
            pairsNeedingUpdate.append(updatedPair)
            didMutate = true
        }

        let updatedPairsByID = Dictionary(uniqueKeysWithValues: pairsNeedingUpdate.map { ($0.id, $0) })
        let reconciledPairs = pairs.map { updatedPairsByID[$0.id] ?? $0 }
        let sortedAccounts = accounts.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return (sortedAccounts, reconciledPairs, didMutate)
    }

    public static func normalizeRemoteName(_ remoteName: String) -> String {
        remoteName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
    }

    public static func suggestedRemoteName(for displayName: String, existingAccounts: [YandexAccount]) -> String {
        let base = normalizeRemoteName(displayName)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        let seed = base.isEmpty ? "macyad-yandex" : "macyad-\(base)"
        var candidate = seed
        var suffix = 2
        let existing = Set(existingAccounts.map { $0.remoteName.lowercased() })

        while existing.contains(candidate.lowercased()) {
            candidate = "\(seed)-\(suffix)"
            suffix += 1
        }

        return candidate
    }
}
