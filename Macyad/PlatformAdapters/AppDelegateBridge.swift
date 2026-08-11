import AppKit
import MacyadCore
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private weak var mainWindow: NSWindow?
    private var statusBarBridge: StatusBarBridge?
    private var didApplyInitialLaunchBehavior = false
    var notificationRouteHandler: @MainActor (ActivityRouteToken?) -> Void = { _ in }

    func applicationWillFinishLaunching(_ notification: Notification) {
        let launchMode = AppLaunchMode(arguments: ProcessInfo.processInfo.arguments)
        guard !launchMode.usesEphemeralPaths, let runningApp = otherRunningInstance() else {
            return
        }

        runningApp.unhide()
        runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        // ponytail: exit(0), not NSApp.terminate — the duplicate must not bootstrap
        // AppEnvironment and race the running instance over Application Support state.
        exit(0)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchMode = AppLaunchMode(arguments: ProcessInfo.processInfo.arguments)
        applyApplicationIcon()
        NSApp.setActivationPolicy(launchMode.shouldForceForegroundWindow ? .regular : .accessory)
        UNUserNotificationCenter.current().delegate = self
        openMainWindowIfLaunchDidNotCreateOne()
        // Статус-бар создаётся из MacyadApp.onAppear с реальным MenuBarPopoverView:
        // NSPopover фиксирует contentSize по первому контенту, и заготовка из
        // EmptyView оставляет popover нулевого размера навсегда.
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

    /// SwiftUI creates the `WindowGroup` window in response to the
    /// `kAEOpenApplication` event LaunchServices sends on a normal launch.
    /// A process started directly — XCUITest spawns the binary rather than
    /// going through LaunchServices — never receives it, so the app comes up
    /// windowless: menu bar item present, nothing on screen, and every
    /// accessibility query finds zero windows. Deliver the event to ourselves
    /// when no window showed up on its own.
    private func openMainWindowIfLaunchDidNotCreateOne() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.mainWindow == nil else { return }

            let event = NSAppleEventDescriptor.appleEvent(
                withEventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEOpenApplication),
                targetDescriptor: NSAppleEventDescriptor(
                    processIdentifier: ProcessInfo.processInfo.processIdentifier
                ),
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )
            try? event.sendEvent(options: .noReply, timeout: 2)
        }
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

    func configureStatusBar(rootView: AnyView) {
        if let statusBarBridge {
            statusBarBridge.update(rootView: rootView)
        } else {
            statusBarBridge = StatusBarBridge(rootView: rootView)
        }
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

    private func otherRunningInstance() -> NSRunningApplication? {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: AppMetadata.bundleIdentifier)
            .first { $0.processIdentifier != currentPID && !$0.isTerminated }
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

@MainActor
final class IssueReviewWindowBridge: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let preferredMinimumSize = CGSize(width: 980, height: 660)

    func present<Content: View>(
        title: String,
        presentingWindow: NSWindow?,
        @ViewBuilder content: () -> Content
    ) {
        let hostingController = NSHostingController(rootView: content())
        let window = existingWindow(title: title) ?? makeWindow(
            title: title,
            presentingWindow: presentingWindow
        )

        window.contentViewController = hostingController
        window.title = title
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow, closingWindow === window else {
            return
        }

        window = nil
    }

    private func existingWindow(title: String) -> NSWindow? {
        guard let window else {
            return nil
        }

        window.title = title
        return window
    }

    private func makeWindow(title: String, presentingWindow: NSWindow?) -> NSWindow {
        let screen = presentingWindow?.screen ?? NSApp.mainWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1160, height: 780)
        let defaultFrame = IssueReviewWindowLayout.defaultFrame(
            for: visibleFrame,
            preferredMinimumSize: preferredMinimumSize
        )
        let minimumSize = IssueReviewWindowLayout.clampedMinimumSize(
            for: visibleFrame,
            preferredMinimumSize: preferredMinimumSize
        )

        let window = NSWindow(
            contentRect: defaultFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = title
        window.minSize = minimumSize
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.delegate = self
        window.setFrame(defaultFrame, display: true)

        self.window = window
        return window
    }
}
