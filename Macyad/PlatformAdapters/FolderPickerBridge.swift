import AppKit
import MacyadCore

struct FolderPickerBridge: FolderPicking {
    func pickFolder() -> (bookmark: Data, displayPath: String)? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        guard let bookmark = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return nil
        }

        return (bookmark, url.path)
    }
}
