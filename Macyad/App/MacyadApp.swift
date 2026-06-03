import AppKit
import MacyadCore
import SwiftUI

@main
struct MacyadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegateBridge.self) private var appDelegate
    @StateObject private var environment = MacyadApp.bootstrapEnvironment()
    @StateObject private var appModel = AppModel()
    @State private var statusBarBridge: StatusBarBridge?
    @State private var backgroundSyncController: BackgroundSyncController?
    @State private var issueReviewWindowBridge = IssueReviewWindowBridge()
    @State private var liveMonitorBridge = LiveMonitorWindowBridge()

    var body: some Scene {
        WindowGroup(AppMetadata.displayName) {
            MainWindowView()
                .environmentObject(environment)
                .environmentObject(appModel)
                .background(
                    WindowAccessor { window in
                        appDelegate.attachMainWindow(
                            window,
                            hideOnInitialLaunch: !environment.launchMode.shouldForceForegroundWindow
                        )
                    }
                )
                .onAppear {
                    configureAppModel()
                    configureStatusBar()
                    syncPreferencesState()
                    refreshOnboardingState()
                    startBackgroundSyncIfNeeded()
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView(viewModel: environment.settingsViewModel)
                .environmentObject(appModel)
        }
    }

    private static func bootstrapEnvironment() -> AppEnvironment {
        do {
            return try AppEnvironment.bootstrap()
        } catch {
            fatalError("Failed to bootstrap AppEnvironment: \(error)")
        }
    }

    private func configureAppModel() {
        environment.settingsViewModel.languageDidChange = { language in
            appModel.language = language
            AppLanguageState.update(language)
            appModel.refreshStatusSummary(using: environment.statusService)
        }
        appModel.openMainWindow = {
            appDelegate.showMainWindow()
        }
        appModel.quitApplication = {
            NSApp.terminate(nil)
        }
        appModel.presentIssueReviewWindow = { [weak appModel] presentingWindow, issueSet, onApply in
            guard let appModel else {
                return
            }

            issueReviewWindowBridge.present(
                title: appModel.copy.issueReviewTitle,
                presentingWindow: presentingWindow
            ) {
                IssueReviewSheetView(issueSet: issueSet, onApply: onApply) {
                    issueReviewWindowBridge.close()
                }
                .environmentObject(appModel)
            }
        }
        appModel.closeIssueReviewWindow = {
            issueReviewWindowBridge.close()
        }
        appDelegate.notificationRouteHandler = { routeToken in
            appDelegate.showMainWindow()
            if let routeToken {
                appModel.applyActivityRoute(routeToken)
            }
        }
        appModel.liveMonitorPresenter = liveMonitorBridge
        appModel.openLiveMonitor = { [weak appModel] pair in
            guard let appModel else { return }
            liveMonitorBridge.present(
                pair: pair,
                viewModel: liveMonitorBridge.existingViewModel(for: pair.id) ?? LiveMonitorViewModel(),
                copy: appModel.copy,
                restartIfExisting: true
            )
        }
    }

    private func configureStatusBar() {
        let rootView = AnyView(
            MenuBarPopoverView()
                .environmentObject(appModel)
        )

        if let statusBarBridge {
            statusBarBridge.update(rootView: rootView)
        } else {
            self.statusBarBridge = StatusBarBridge(rootView: rootView)
        }
    }

    private func syncPreferencesState() {
        Task {
            await environment.settingsViewModel.loadIfNeeded()
        }
    }

    private func refreshOnboardingState() {
        Task { @MainActor in
            await environment.onboardingViewModel.retry()
            appModel.applyOnboardingState(environment.onboardingViewModel.state, using: environment.statusService)
        }
    }

    private func startBackgroundSyncIfNeeded() {
        if let backgroundSyncController {
            appModel.refreshBackgroundState = {
                Task {
                    await backgroundSyncController.refreshState()
                }
            }
            return
        }

        let controller = environment.makeBackgroundSyncController { pairs, events in
            await MainActor.run {
                appModel.applyPersistedState(
                    pairs: pairs,
                    accounts: appModel.accounts,
                    events: events,
                    using: environment.statusService
                )
            }

            let selectedPair = await MainActor.run { appModel.selectedPair }
            await environment.pairDetailViewModel.load(for: selectedPair)
        }

        backgroundSyncController = controller
        appModel.refreshBackgroundState = {
            Task {
                await controller.refreshState()
            }
        }

        Task {
            await controller.start()
        }
    }
}
