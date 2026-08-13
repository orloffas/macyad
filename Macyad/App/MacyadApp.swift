import AppKit
import MacyadCore
import SwiftUI

@main
struct MacyadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegateBridge.self) private var appDelegate
    // Владелец состояния — AppCoordinator, а не сцена: при автозапуске окна
    // может не быть вовсе, а статус-бар и фоновая синхронизация нужны всё равно.
    //
    // Обращение к синглтону идёт только через autoclosure `@StateObject` и из
    // замыканий: хранимое свойство подняло бы `AppEnvironment` ещё до
    // `applicationWillFinishLaunching`, и дубликат процесса успел бы создать
    // каталоги в Application Support прежде, чем завершиться.
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
                    AppCoordinator.shared.refreshOnboardingState()
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
