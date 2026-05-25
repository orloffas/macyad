import MacyadCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 16) {
            Text(copy.onboardingTitle)
                .font(.title2)
                .fontWeight(.semibold)

            switch viewModel.state.step {
            case .installRclone:
                CommandCopyRowView(
                    title: copy.installRcloneTitle,
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
                    title: copy.createRemoteTitle,
                    command: viewModel.state.remoteCreateCommand,
                    copied: viewModel.lastCopiedCommand == viewModel.state.remoteCreateCommand,
                    accessibilityIdentifier: nil
                ) {
                    viewModel.copy(viewModel.state.remoteCreateCommand)
                }

            case .createFirstPair:
                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.createFirstPairHint)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Button(copy.newPairButtonTitle) {
                        appModel.isCreatePairSheetPresented = true
                    }
                    .accessibilityIdentifier("pair.new")
                }

            case .complete:
                Text(copy.setupComplete)
                    .foregroundStyle(.secondary)
            }

            Button(copy.retryButtonTitle) {
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
