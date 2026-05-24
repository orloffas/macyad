import MacyadCore
import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppModel.self) private var appModel
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("onboarding.title")
                .font(.title2)
                .fontWeight(.semibold)

            switch viewModel.state.step {
            case .installRclone:
                CommandCopyRowView(
                    title: "onboarding.install_rclone",
                    command: viewModel.state.brewInstallCommand,
                    copied: viewModel.lastCopiedCommand == viewModel.state.brewInstallCommand
                ) {
                    viewModel.copy(viewModel.state.brewInstallCommand)
                }

            case .configureRemote:
                if let location = viewModel.state.rcloneLocation {
                    LabeledContent("rclone", value: location)
                    .foregroundStyle(.secondary)
                }

                CommandCopyRowView(
                    title: "onboarding.create_remote",
                    command: viewModel.state.remoteCreateCommand,
                    copied: viewModel.lastCopiedCommand == viewModel.state.remoteCreateCommand
                ) {
                    viewModel.copy(viewModel.state.remoteCreateCommand)
                }

            case .createFirstPair:
                Text("onboarding.create_pair_hint")
                    .foregroundStyle(.secondary)

            case .complete:
                Text("onboarding.complete")
                    .foregroundStyle(.secondary)
            }

            Button("onboarding.retry") {
                Task { await refresh() }
            }
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
        appModel.onboardingState = viewModel.state
        appModel.refreshStatusSummary(using: environment.statusService)
    }
}
