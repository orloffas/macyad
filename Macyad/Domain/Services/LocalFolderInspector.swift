import Foundation

public protocol LocalFolderInspecting: Sendable {
    func containsUserVisibleContent(atPath path: String) throws -> Bool
}

public struct FileManagerLocalFolderInspector: LocalFolderInspecting {
    public init() {}

    public func containsUserVisibleContent(atPath path: String) throws -> Bool {
        let itemNames = try FileManager.default.contentsOfDirectory(atPath: path)

        return itemNames.contains { itemName in
            !itemName.hasPrefix(".")
        }
    }
}
