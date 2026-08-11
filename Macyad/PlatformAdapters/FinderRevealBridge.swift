import AppKit
import Foundation

@MainActor
protocol FolderRevealing {
    func revealFolder(atPath path: String)
}

@MainActor
struct FinderRevealBridge: FolderRevealing {
    func revealFolder(atPath path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: path, isDirectory: true)
        ])
    }
}
