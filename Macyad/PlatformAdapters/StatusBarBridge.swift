import AppKit
import SwiftUI

@MainActor
final class StatusBarBridge: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let hostingController = NSHostingController(rootView: AnyView(EmptyView()))

    init(rootView: AnyView) {
        super.init()

        // autosaveName даёт item стабильную идентичность между запусками — без него
        // menu bar managers (Bartender, Ice) видят каждый запуск как новую иконку.
        item.autosaveName = "\(AppMetadata.bundleIdentifier).statusItem"
        item.isVisible = true
        item.button?.image = NSImage(named: "MenuBarTemplate") ?? NSImage(
            systemSymbolName: "externaldrive.badge.icloud",
            accessibilityDescription: AppMetadata.displayName
        )
        item.button?.image?.isTemplate = true
        item.button?.setAccessibilityLabel(AppMetadata.displayName)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))

        popover.behavior = .transient
        popover.contentViewController = hostingController
        update(rootView: rootView)
    }

    func update(rootView: AnyView) {
        hostingController.rootView = rootView
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = item.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
