import AppKit
import SwiftUI

@MainActor
final class StatusBarBridge: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let hostingController: NSHostingController<AnyView>

    init(rootView: AnyView) {
        hostingController = NSHostingController(rootView: rootView)
        super.init()

        // ponytail: без autosaveName. Bartender разбирает идентификатор элемента
        // как "<bundle-id>-<имя>", и autosaveName вида "me.orloff.macyad.statusItem"
        // ломает разбор — элемент записывается на сам Bartender и перестаёт
        // переноситься между секциями. Позиционный "Item-0" его устраивает.
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
            // NSPopover не наследует размер от NSHostingController — без этого
            // contentSize остаётся {0, 0} и popover открывается невидимым.
            // Пересчитываем каждый раз: высота зависит от списка recent events.
            popover.contentSize = hostingController.view.fittingSize
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
