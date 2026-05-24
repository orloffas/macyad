import AppKit

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private weak var mainWindow: NSWindow?
    private var didApplyInitialLaunchBehavior = false

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

        guard hideOnInitialLaunch, !didApplyInitialLaunchBehavior else {
            return
        }

        didApplyInitialLaunchBehavior = true
        window.orderOut(nil)
    }

    func showMainWindow() {
        guard let mainWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow.deminiaturize(nil)
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.orderFrontRegardless()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
