import AppKit
import MacyadCore
import SwiftUI

@main
struct MacyadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegateBridge.self) private var appDelegate
    @State private var environment = MacyadApp.bootstrapEnvironment()
    @State private var appModel = AppModel()
    @State private var statusBarBridge: StatusBarBridge?

    var body: some Scene {
        WindowGroup(AppMetadata.displayName) {
            MainWindowView()
                .environment(environment)
                .environment(appModel)
                .background(
                    WindowAccessor { window in
                        appDelegate.attachMainWindow(window)
                        if environment.launchMode.shouldForceForegroundWindow {
                            appDelegate.showMainWindow()
                        }
                    }
                )
                .onAppear {
                    appModel.refreshStatusSummary(using: environment.statusService)
                    appModel.openMainWindow = {
                        appDelegate.showMainWindow()
                    }

                    let rootView = AnyView(
                        MenuBarPopoverView()
                            .environment(appModel)
                    )

                    if let statusBarBridge {
                        statusBarBridge.update(rootView: rootView)
                    } else {
                        self.statusBarBridge = StatusBarBridge(rootView: rootView)
                    }
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
}
