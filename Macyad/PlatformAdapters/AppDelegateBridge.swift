import AppKit
import MacyadCore
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegateBridge: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private weak var mainWindow: NSWindow?
    private var statusBarBridge: StatusBarBridge?
    /// Окно, созданное SwiftUI при автозапуске, надо спрятать: приложение
    /// должно подняться только в меню-баре. Сбрасывается, как только окно
    /// запросили явно — из меню-бара, из уведомления или кликом по Dock.
    private var hidesWindowOnAttach = false
    /// Идёт окно ожидания активации: решение «ручной запуск или автозапуск»
    /// ещё не принято.
    private var isWaitingForUserActivation = false
    /// Окно измеряется кадрами, а не секундами: активация от LaunchServices
    /// приходит сразу за `didFinishLaunching`, а вот клик по иконке в меню-баре
    /// тоже активирует приложение — и при длинном окне открывал бы главное окно
    /// вместо поповера. Столько времени человеку на клик не хватит.
    private static let userActivationGrace: TimeInterval = 0.6
    /// Запрос на создание окна отправлен и окно ещё не привязано. Без этого
    /// два клика подряд дают два окна.
    private var isMainWindowRequestPending = false
    private static let mainWindowRequestTimeout: TimeInterval = 2
    var notificationRouteHandler: @MainActor (ActivityRouteToken?) -> Void = { _ in }

    func applicationWillFinishLaunching(_ notification: Notification) {
        let launchMode = AppLaunchMode(arguments: ProcessInfo.processInfo.arguments)
        guard !launchMode.usesEphemeralPaths, let runningApp = otherRunningInstance() else {
            return
        }

        runningApp.unhide()
        runningApp.activate(options: [.activateAllWindows])
        // ponytail: exit(0), not NSApp.terminate — the duplicate must not bootstrap
        // AppEnvironment and race the running instance over Application Support state.
        exit(0)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchMode = AppLaunchMode(arguments: ProcessInfo.processInfo.arguments)
        let presentsWindow = launchMode.presentsWindowOnLaunch(isUserActivated: NSApp.isActive)

        applyApplicationIcon()
        NSApp.setActivationPolicy(presentsWindow ? .regular : .accessory)
        UNUserNotificationCenter.current().delegate = self
        // Статус-бар и фоновая синхронизация поднимаются здесь, а не из onAppear
        // окна: при автозапуске окна нет, а работать приложение обязано.
        AppCoordinator.shared.start(delegate: self)

        guard presentsWindow else {
            hidesWindowOnAttach = true
            waitForUserActivation()
            return
        }

        // На старте окно ждём от SwiftUI: событие уходит, только если своего
        // окна так и не появилось.
        openMainWindowIfMissing(after: 0.5)
    }

    /// Ждёт, окажется ли приложение на переднем плане: пользовательский запуск
    /// LaunchServices активирует, автозапуск login item'ом — нет.
    ///
    /// Решение принимается двумя путями, потому что ни один из них не полон:
    /// нотификация может прийти раньше конца окна, а может не прийти вовсе,
    /// если активация случилась ещё до `didFinishLaunching`. Поэтому на исходе
    /// окна состояние читается напрямую.
    private func waitForUserActivation() {
        isWaitingForUserActivation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.userActivationGrace) { [weak self] in
            guard let self, self.isWaitingForUserActivation else { return }

            self.isWaitingForUserActivation = false

            guard NSApp.isActive else { return }

            self.showMainWindow()
        }
    }

    /// Приложение вывели на передний план. Внутри окна ожидания это значит, что
    /// запуск был пользовательским. Позже — обычная активация, окно трогать
    /// нельзя, иначе клик по иконке в меню-баре открывал бы главное окно.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard isWaitingForUserActivation else {
            return
        }

        isWaitingForUserActivation = false
        showMainWindow()
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

    /// Просит SwiftUI материализовать окно `WindowGroup`, если его нет.
    ///
    /// Окно создаётся в ответ на `kAEOpenApplication`, который LaunchServices
    /// шлёт при обычном запуске. Процесс, запущенный напрямую (так делает
    /// XCUITest) или поднятый автозапуском, этого события не получает и
    /// остаётся без окна, поэтому событие досылается себе. Отправка отложена:
    /// SwiftUI мог создать окно сам, а второе событие при нулевом числе окон
    /// дало бы второе окно.
    private func openMainWindowIfMissing(after delay: TimeInterval) {
        guard !isMainWindowRequestPending else {
            return
        }

        isMainWindowRequestPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }

            guard self.mainWindow == nil else {
                self.isMainWindowRequestPending = false
                return
            }

            self.sendOpenApplicationEventToSelf()
            // Флаг снимает attachMainWindow(_:), когда окно появится. Здесь —
            // страховка на случай, когда оно так и не появилось: иначе запрос
            // заблокировал бы все следующие попытки навсегда.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.mainWindowRequestTimeout) { [weak self] in
                self?.isMainWindowRequestPending = false
            }
        }
    }

    private func sendOpenApplicationEventToSelf() {
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenApplication),
            targetDescriptor: NSAppleEventDescriptor(
                processIdentifier: ProcessInfo.processInfo.processIdentifier
            ),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        _ = try? event.sendEvent(options: .noReply, timeout: 2)
    }

    func attachMainWindow(_ window: NSWindow) {
        applyMainWindowSizePolicy(to: window)
        applyApplicationIcon()
        isMainWindowRequestPending = false

        guard mainWindow !== window else {
            return
        }

        mainWindow = window
        window.delegate = self

        if hidesWindowOnAttach {
            hidesWindowOnAttach = false
            hideMainWindow(window)
        } else {
            showMainWindow()
        }
    }

    func showMainWindow() {
        applyApplicationIcon()
        // Политика меняется до вывода окна: приложению в .accessory Window
        // Server не отдаёт key window, и окно осталось бы под чужими.
        NSApp.setActivationPolicy(.regular)
        hidesWindowOnAttach = false
        isWaitingForUserActivation = false

        guard let mainWindow else {
            // Окна нет вовсе — так поднимается автозапуск. Пусть SwiftUI создаст
            // его: attachMainWindow(_:) доведёт показ до конца. Задержка здесь
            // только чтобы схлопнуть повторные запросы, поэтому короткая.
            openMainWindowIfMissing(after: 0.15)
            return
        }

        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }

        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate()
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
        NSApp.activate()
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
