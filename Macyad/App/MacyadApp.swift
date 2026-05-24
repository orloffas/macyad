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
                        if environment.launchMode.shouldForceForegroundWindow {
                            appDelegate.showMainWindow()
                        }
                    }
                )
                .onAppear {
                    configureAppModel()
                    configureStatusBar()
                    refreshOnboardingState()
                    startBackgroundSyncIfNeeded()
                }
        }

        Settings {
            SettingsView(viewModel: environment.settingsViewModel)
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
        appModel.openMainWindow = {
            appDelegate.showMainWindow()
        }
        appModel.openSettings = {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        appModel.quitApplication = {
            NSApp.terminate(nil)
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
                appModel.applyPersistedState(pairs: pairs, events: events, using: environment.statusService)
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
