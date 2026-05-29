import AppKit
import MacyadCore
import UserNotifications

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private weak var mainWindow: NSWindow?
    private var didApplyInitialLaunchBehavior = false
    var notificationRouteHandler: @MainActor (ActivityRouteToken?) -> Void = { _ in }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchMode = AppLaunchMode(arguments: ProcessInfo.processInfo.arguments)
        applyApplicationIcon()
        NSApp.setActivationPolicy(launchMode.shouldForceForegroundWindow ? .regular : .accessory)
        UNUserNotificationCenter.current().delegate = self
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
        applyApplicationIcon()

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

        applyApplicationIcon()
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
        applyApplicationIcon()
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

    private func applyApplicationIcon() {
        guard let iconImage = makeApplicationIcon() else {
            return
        }

        iconImage.isTemplate = false
        NSApp.applicationIconImage = iconImage
        NSApp.dockTile.display()
    }

    private func makeApplicationIcon() -> NSImage? {
        if let bundleIcon = bundledApplicationIcon() {
            return bundleIcon
        }

        if let bundledImage = NSImage(named: "AppIcon")?.copy() as? NSImage {
            return bundledImage
        }

        return NSImage(
            systemSymbolName: "externaldrive.badge.icloud",
            accessibilityDescription: AppMetadata.displayName
        )?.copy() as? NSImage
    }

    private func bundledApplicationIcon() -> NSImage? {
        let info = Bundle.main.infoDictionary ?? [:]
        let iconFileValue = (info["CFBundleIconFile"] as? String) ?? (info["CFBundleIconName"] as? String)
        guard let iconFileValue, !iconFileValue.isEmpty else {
            return nil
        }

        let resourceName = (iconFileValue as NSString).deletingPathExtension
        let resourceExtension = (iconFileValue as NSString).pathExtension.isEmpty
            ? "icns"
            : (iconFileValue as NSString).pathExtension

        guard let iconURL = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
              let iconImage = NSImage(contentsOf: iconURL)?.copy() as? NSImage else {
            return nil
        }

        return iconImage
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let routeToken = ActivityRouteToken(notificationUserInfo: response.notification.request.content.userInfo)
        await MainActor.run {
            self.notificationRouteHandler(routeToken)
        }
    }
}
