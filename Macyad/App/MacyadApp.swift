import AppKit
import MacyadCore
import SwiftUI

@main
struct MacyadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegateBridge.self) private var appDelegate
    // Владелец состояния — AppCoordinator, а не сцена: при автозапуске окна
    // может не быть вовсе, а статус-бар и фоновая синхронизация нужны всё равно.
    private let coordinator = AppCoordinator.shared
    @StateObject private var environment = AppCoordinator.shared.environment
    @StateObject private var appModel = AppCoordinator.shared.appModel

    var body: some Scene {
        WindowGroup(AppMetadata.displayName) {
            MainWindowView()
                .environmentObject(environment)
                .environmentObject(appModel)
                .background(
                    WindowAccessor { window in
                        appDelegate.attachMainWindow(window)
                    }
                )
                .onAppear {
                    // Окно могли открыть спустя часы после старта: rclone за это
                    // время мог появиться или пропасть.
                    coordinator.refreshOnboardingState()
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
}
