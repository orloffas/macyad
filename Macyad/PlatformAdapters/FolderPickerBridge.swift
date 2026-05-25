import AppKit
import MacyadCore

@MainActor
struct FolderPickerBridge: FolderPicking {
    func pickFolder() -> (bookmark: Data, displayPath: String)? {
        let copy = AppCopy.current
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.title = copy.folderPickerTitle
        panel.prompt = copy.folderPickerPrompt

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
