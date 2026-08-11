import AppKit
import MacyadCore
import UniformTypeIdentifiers

@MainActor
protocol ConfigurationFilePicking {
    func pickExportDestination() -> URL?
    func pickImportSource() -> URL?
    /// A fresh bookmark for a folder named by an imported pair. Bookmarks are
    /// machine-specific, so an import has to make its own.
    func bookmark(forFolderAt path: String) -> Data?
}

@MainActor
struct ConfigurationFilePanelBridge: ConfigurationFilePicking {
    func pickExportDestination() -> URL? {
        let copy = AppCopy.current
        let panel = NSSavePanel()
        panel.title = copy.configurationExportPanelTitle
        panel.message = copy.configurationExportHint
        panel.nameFieldStringValue = copy.configurationExportFileName(for: Date())
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    func pickImportSource() -> URL? {
        let copy = AppCopy.current
        let panel = NSOpenPanel()
        panel.title = copy.configurationImportPanelTitle
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    func bookmark(forFolderAt path: String) -> Data? {
        try? URL(fileURLWithPath: path, isDirectory: true).bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
