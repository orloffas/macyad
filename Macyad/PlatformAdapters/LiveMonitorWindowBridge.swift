import AppKit
import SwiftUI
import MacyadCore

@MainActor
final class LiveMonitorWindowBridge: NSObject, LiveMonitorPresenting {
    private var viewModels: [UUID: LiveMonitorViewModel] = [:]
    private var windows: [UUID: NSWindowController] = [:]
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    func ensureViewModel(for pairID: UUID) -> LiveMonitorViewModel {
        if let existing = viewModels[pairID] { return existing }
        let fresh = LiveMonitorViewModel()
        viewModels[pairID] = fresh
        return fresh
    }

    func viewModel(for pairID: UUID) -> LiveMonitorViewModel? {
        viewModels[pairID]
    }

    func hasLog(for pairID: UUID) -> Bool {
        viewModels[pairID] != nil
    }

    func present(pair: SyncPair, copy: AppCopy) {
        if let controller = windows[pair.id] {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let viewModel = ensureViewModel(for: pair.id)
        let hostingController = NSHostingController(rootView: LiveMonitorView(viewModel: viewModel, copy: copy))
        let window = NSWindow(contentViewController: hostingController)
        window.title = copy.liveMonitorWindowTitle(pair.name)
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.center()
        let controller = NSWindowController(window: window)
        windows[pair.id] = controller

        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let closingWindow = notification.object as? NSWindow
            Task { @MainActor [weak self] in
                guard let self, let closingWindow,
                      let entry = self.windows.first(where: { $0.value.window === closingWindow })
                else { return }
                self.windows.removeValue(forKey: entry.key)
            }
        }
        observers.append(observer)
        controller.showWindow(nil)
    }

    func close(pairID: UUID) {
        windows[pairID]?.close()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
