import AppKit
import SwiftUI
import MacyadCore

@MainActor
final class LiveMonitorWindowBridge: NSObject, LiveMonitorPresenting {
    private struct WindowKey: Hashable {
        let pairID: UUID
        let slot: LiveMonitorSlot
    }

    private var runningViewModels: [UUID: LiveMonitorViewModel] = [:]
    private var archivedViewModels: [UUID: LiveMonitorViewModel] = [:]
    private var windows: [WindowKey: NSWindowController] = [:]
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    func ensureRunningViewModel(for pairID: UUID) -> LiveMonitorViewModel {
        if let existing = runningViewModels[pairID] { return existing }
        let fresh = LiveMonitorViewModel()
        runningViewModels[pairID] = fresh
        return fresh
    }

    func archiveRunningLog(for pairID: UUID) {
        guard let vm = runningViewModels[pairID] else { return }
        archivedViewModels[pairID] = vm
        runningViewModels[pairID] = nil
    }

    func hasArchivedLog(for pairID: UUID) -> Bool {
        archivedViewModels[pairID] != nil
    }

    func hasRunningLog(for pairID: UUID) -> Bool {
        runningViewModels[pairID] != nil
    }

    func present(pair: SyncPair, slot: LiveMonitorSlot, copy: AppCopy) {
        let key = WindowKey(pairID: pair.id, slot: slot)
        if let controller = windows[key] {
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let viewModel: LiveMonitorViewModel?
        switch slot {
        case .running:  viewModel = runningViewModels[pair.id]
        case .archived: viewModel = archivedViewModels[pair.id]
        }
        guard let viewModel else { return }

        let titleSuffix: String
        switch slot {
        case .running:  titleSuffix = " — \(copy.liveMonitorRunningSlotSuffix)"
        case .archived: titleSuffix = " — \(copy.liveMonitorArchivedSlotSuffix)"
        }

        let hostingController = NSHostingController(rootView: LiveMonitorView(viewModel: viewModel, copy: copy))
        let window = NSWindow(contentViewController: hostingController)
        window.title = copy.liveMonitorWindowTitle(pair.name) + titleSuffix
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.center()
        let controller = NSWindowController(window: window)
        windows[key] = controller

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

    func close(pairID: UUID, slot: LiveMonitorSlot) {
        let key = WindowKey(pairID: pairID, slot: slot)
        windows[key]?.close()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
