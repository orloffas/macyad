import AppKit
import MacyadCore
import SwiftUI

/// Владелец состояния приложения, не зависящий от окна.
///
/// Раньше всё связывание — статус-бар, замыкания `AppModel`, фоновая
/// синхронизация — висело на `.onAppear` у `MainWindowView`. При автозапуске
/// на входе в систему SwiftUI не создаёт окно `WindowGroup`, поэтому `.onAppear`
/// не вызывался: приложение поднималось без иконки в меню-баре и без
/// фоновой синхронизации, а `showMainWindow()` молчал, потому что окна не было.
/// Здесь то же связывание выполняется из `applicationDidFinishLaunching`, а
/// контент окна только подписывается на готовые объекты.
@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    let environment: AppEnvironment
    let appModel = AppModel()

    private let issueReviewWindowBridge = IssueReviewWindowBridge()
    private let liveMonitorBridge = LiveMonitorWindowBridge()
    private var backgroundSyncController: BackgroundSyncController?
    private var didStart = false

    private init() {
        do {
            environment = try AppEnvironment.bootstrap()
        } catch {
            fatalError("Failed to bootstrap AppEnvironment: \(error)")
        }
    }

    /// Идемпотентно: вызывается из делегата приложения на старте.
    func start(delegate: AppDelegateBridge) {
        guard !didStart else {
            return
        }

        didStart = true
        configureAppModel(delegate: delegate)
        configureStatusBar(delegate: delegate)
        syncPreferencesState()
        refreshOnboardingState()
        startBackgroundSync()
    }

    func refreshOnboardingState() {
        Task { @MainActor in
            await environment.onboardingViewModel.retry(pairCount: appModel.pairs.count)
            appModel.applyOnboardingState(environment.onboardingViewModel.state, using: environment.statusService)
        }
    }

    private func configureAppModel(delegate: AppDelegateBridge) {
        // Замыкания живут внутри settingsViewModel, который держит сам
        // environment: сильный захват замкнул бы граф на себя.
        environment.settingsViewModel.languageDidChange = { [weak environment, weak appModel] language in
            guard let environment, let appModel else {
                return
            }

            appModel.language = language
            AppLanguageState.update(language)
            appModel.refreshStatusSummary(using: environment.statusService)
        }
        environment.settingsViewModel.preferencesDidChange = { [weak appModel] preferences in
            appModel?.preferences = preferences
        }
        environment.settingsViewModel.configurationDidImport = { [weak appModel, weak environment] pairs, accounts in
            guard let appModel, let environment else {
                return
            }

            appModel.applyPersistedState(
                pairs: pairs,
                accounts: accounts,
                events: appModel.events(for: nil),
                using: environment.statusService
            )
            appModel.refreshBackgroundState()
        }
        appModel.openMainWindow = { [weak delegate] in
            delegate?.showMainWindow()
        }
        appModel.quitApplication = {
            NSApp.terminate(nil)
        }
        appModel.presentIssueReviewWindow = { [weak appModel, issueReviewWindowBridge] presentingWindow, issueSet, onApply in
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
        appModel.closeIssueReviewWindow = { [issueReviewWindowBridge] in
            issueReviewWindowBridge.close()
        }
        appModel.liveMonitorPresenter = liveMonitorBridge
        appModel.openLiveMonitor = { [weak appModel, liveMonitorBridge] pair, slot in
            guard let appModel else { return }
            liveMonitorBridge.present(pair: pair, slot: slot, copy: appModel.copy)
        }
        delegate.notificationRouteHandler = { [weak delegate, weak appModel] routeToken in
            delegate?.showMainWindow()
            if let routeToken {
                appModel?.applyActivityRoute(routeToken)
            }
        }
    }

    private func configureStatusBar(delegate: AppDelegateBridge) {
        let rootView = AnyView(
            MenuBarPopoverView()
                .environmentObject(appModel)
        )

        delegate.configureStatusBar(rootView: rootView)
    }

    private func syncPreferencesState() {
        Task {
            await environment.settingsViewModel.loadIfNeeded()
        }
    }

    private func startBackgroundSync() {
        let bridge = liveMonitorBridge
        let scheduledSyncLifecycle = ScheduledSyncLifecycle(
            willStart: { @Sendable pair in
                await MainActor.run {
                    let vm = bridge.ensureRunningViewModel(for: pair.id)
                    vm.clearLog()
                    let operation = AppCopy.current.scheduledSyncOperationName(pair.autoSyncMode)
                    vm.appendLine(
                        "\(SyncService.liveMonitorTimestamp(for: Date())) macyad : ——— Scheduled \(operation) queued for \(pair.name) ———"
                    )
                    return LiveMonitorClosureObserver(
                        onLineCallback: { [weak vm] line in
                            vm?.appendLine(line)
                        }
                    ) as RcloneOutputObserver
                }
            },
            didFinish: { @Sendable [weak appModel] pair in
                await MainActor.run {
                    bridge.archiveRunningLog(for: pair.id)
                    appModel?.pairsWithArchivedLog.insert(pair.id)
                }
            }
        )

        let controller = environment.makeBackgroundSyncController(stateDidChange: { [appModel, environment] pairs, events in
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
        }, scheduledSyncLifecycle: scheduledSyncLifecycle)

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
