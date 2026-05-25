import AppKit

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private weak var mainWindow: NSWindow?
    private var didApplyInitialLaunchBehavior = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func attachMainWindow(_ window: NSWindow, hideOnInitialLaunch: Bool) {
        applyMainWindowSizePolicy(to: window)

        if mainWindow !== window {
            mainWindow = window
            window.delegate = self
        }

        guard !didApplyInitialLaunchBehavior else {
            return
        }

        didApplyInitialLaunchBehavior = true
        if hideOnInitialLaunch {
            hideMainWindow(window)
        } else {
            showMainWindow()
        }
    }

    func showMainWindow() {
        guard let mainWindow else { return }

        NSApp.setActivationPolicy(.regular)

        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }

        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === mainWindow {
            hideMainWindow(sender)
            return false
        }

        return true
    }

    private func hideMainWindow(_ window: NSWindow) {
        window.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    private func applyMainWindowSizePolicy(to window: NSWindow) {
        let minimumSize = NSSize(width: 980, height: 680)
        window.minSize = minimumSize
        window.isRestorable = false

        guard window.frame.width < minimumSize.width || window.frame.height < minimumSize.height else {
            return
        }

        var frame = window.frame
        frame.size.width = max(frame.width, minimumSize.width)
        frame.size.height = max(frame.height, minimumSize.height)
        window.setFrame(frame, display: true)
    }
}
