import AppKit
import Foundation

@MainActor
protocol FolderOpening {
    func openFolder(atPath path: String)
}

@MainActor
struct FinderFolderOpenerBridge: FolderOpening {
    /// Opens the folder itself rather than selecting it in its parent
    /// (`activateFileViewerSelecting`): the rows this backs name a folder the
    /// user wants to look inside.
    ///
    /// No `fileExists` check first — the app is not sandboxed but relies on
    /// TCC, and a folder we have no read permission for reports as missing,
    /// which would disable a button that works perfectly well. A missing
    /// folder simply does nothing here, which Finder makes obvious.
    func openFolder(atPath path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
    }
}
