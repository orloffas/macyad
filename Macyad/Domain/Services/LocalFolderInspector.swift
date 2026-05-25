import Foundation

public protocol LocalFolderInspecting: Sendable {
    func containsUserVisibleContent(atPath path: String) throws -> Bool
}

public struct FileManagerLocalFolderInspector: LocalFolderInspecting {
    private static let ignoredTopLevelNames: Set<String> = [
        ".DS_Store",
        ".localized"
    ]

    public init() {}

    public func containsUserVisibleContent(atPath path: String) throws -> Bool {
        let itemNames = try FileManager.default.contentsOfDirectory(atPath: path)

        return itemNames.contains { itemName in
            !Self.ignoredTopLevelNames.contains(itemName)
                && !itemName.hasPrefix("._")
        }
    }
}
