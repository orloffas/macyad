import AppKit
import MacyadCore

final class PasteboardBridge: PasteboardWriting {
    func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
