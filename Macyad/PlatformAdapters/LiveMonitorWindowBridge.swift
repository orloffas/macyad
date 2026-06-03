import AppKit
import SwiftUI
import MacyadCore

@MainActor
final class LiveMonitorWindowBridge: NSObject, LiveMonitorPresenting {
    private struct WindowEntry {
        let controller: NSWindowController
        let viewModel: LiveMonitorViewModel
    }

    private var windows: [UUID: WindowEntry] = [:]
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    func present(pair: SyncPair, viewModel: LiveMonitorViewModel, copy: AppCopy, restartIfExisting: Bool) {
        if let existing = windows[pair.id] {
            existing.controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hostingController = NSHostingController(rootView: LiveMonitorView(viewModel: viewModel, copy: copy))
        let window = NSWindow(contentViewController: hostingController)
        window.title = copy.liveMonitorWindowTitle(pair.name)
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.center()
        let controller = NSWindowController(window: window)
        windows[pair.id] = WindowEntry(controller: controller, viewModel: viewModel)

        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let closingWindow = notification.object as? NSWindow
            Task { @MainActor [weak self] in
                guard let self, let closingWindow,
                      let entry = self.windows.first(where: { $0.value.controller.window === closingWindow })
                else { return }
                self.windows.removeValue(forKey: entry.key)
            }
        }
        observers.append(observer)
        controller.showWindow(nil)
    }

    func close(pairID: UUID) {
        windows[pairID]?.controller.close()
    }

    func existingViewModel(for pairID: UUID) -> LiveMonitorViewModel? {
        windows[pairID]?.viewModel
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
