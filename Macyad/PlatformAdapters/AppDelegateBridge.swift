import AppKit

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private weak var mainWindow: NSWindow?
    private var didApplyInitialLaunchBehavior = false
    private var foregroundActivationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func attachMainWindow(_ window: NSWindow, hideOnInitialLaunch: Bool) {
        guard mainWindow !== window else { return }
        mainWindow = window
        window.delegate = self
        applyMainWindowSizePolicy(to: window)

        guard !didApplyInitialLaunchBehavior else {
            return
        }

        didApplyInitialLaunchBehavior = true
        if hideOnInitialLaunch {
            window.orderOut(nil)
        } else {
            showMainWindow()
        }
    }

    func showMainWindow() {
        guard let mainWindow else { return }
        foregroundActivationTask?.cancel()
        presentMainWindow(mainWindow)

        foregroundActivationTask = Task { @MainActor [weak self, weak mainWindow] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self, let mainWindow, self.mainWindow === mainWindow else { return }
            self.presentMainWindow(mainWindow)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func applyMainWindowSizePolicy(to window: NSWindow) {
        let minimumSize = NSSize(width: 980, height: 680)
        window.minSize = minimumSize

        guard window.frame.width < minimumSize.width || window.frame.height < minimumSize.height else {
            return
        }

        var frame = window.frame
        frame.size.width = max(frame.width, minimumSize.width)
        frame.size.height = max(frame.height, minimumSize.height)
        window.setFrame(frame, display: true)
    }

    private func presentMainWindow(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
