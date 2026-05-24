import MacyadCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Подключение")
                .font(.title2)
                .fontWeight(.semibold)

            switch viewModel.state.step {
            case .installRclone:
                CommandCopyRowView(
                    title: "Установить rclone",
                    command: viewModel.state.brewInstallCommand,
                    copied: viewModel.lastCopiedCommand == viewModel.state.brewInstallCommand,
                    accessibilityIdentifier: "onboarding.copyCommand"
                ) {
                    viewModel.copy(viewModel.state.brewInstallCommand)
                }

            case .configureRemote:
                if let location = viewModel.state.rcloneLocation {
                    LabeledContent("rclone", value: location)
                    .foregroundStyle(.secondary)
                }

                CommandCopyRowView(
                    title: "Создать remote yd для Yandex",
                    command: viewModel.state.remoteCreateCommand,
                    copied: viewModel.lastCopiedCommand == viewModel.state.remoteCreateCommand,
                    accessibilityIdentifier: nil
                ) {
                    viewModel.copy(viewModel.state.remoteCreateCommand)
                }

            case .createFirstPair:
                VStack(alignment: .leading, spacing: 12) {
                    Text("Создайте первую пару после настройки remote.")
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Button("Новая пара") {
                        appModel.isCreatePairSheetPresented = true
                    }
                    .accessibilityIdentifier("pair.new")
                }

            case .complete:
                Text("Настройка завершена.")
                    .foregroundStyle(.secondary)
            }

            Button("Проверить снова") {
                Task { await refresh() }
            }
            .accessibilityIdentifier("onboarding.retry")
            .disabled(viewModel.isRefreshing)

            Spacer()
        }
        .padding(20)
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        await viewModel.retry()
        appModel.applyOnboardingState(viewModel.state, using: environment.statusService)
        appModel.refreshBackgroundState()
    }
}
