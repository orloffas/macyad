import MacyadCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.state.step == .complete ? copy.onboardingEnvironmentTitle : copy.onboardingTitle)
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

                LabeledContent(copy.accountConfigPathLabel, value: viewModel.state.configPath)
                    .foregroundStyle(.secondary)

                CommandCopyRowView(
                    title: copy.createRemoteTitle,
                    command: viewModel.state.remoteCreateCommand,
                    copied: viewModel.lastCopiedCommand == viewModel.state.remoteCreateCommand,
                    accessibilityIdentifier: nil
                ) {
                    viewModel.copy(viewModel.state.remoteCreateCommand)
                }

                Text(copy.onboardingAccountsHint)
                    .foregroundStyle(.secondary)

            case .createFirstPair:
                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.createFirstPairHint)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Button(copy.newPairButtonTitle) {
                        appModel.presentCreatePairSheet()
                    }
                    .accessibilityIdentifier("pair.new")
                }

            case .complete:
                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.onboardingEnvironmentHint)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                        ForEach(viewModel.statusRows(pairs: appModel.pairs, preferences: appModel.preferences, copy: copy), id: \.label) { row in
                            GridRow {
                                Image(systemName: row.isSatisfied ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(row.isSatisfied ? Color.green : Color.orange)
                                Text(row.label)
                                    .foregroundStyle(.secondary)
                                Text(row.value)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .font(.callout)
                }
            }

            HStack(spacing: 10) {
                Button(copy.recheckEnvironmentButtonTitle) {
                    Task { await refresh() }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("onboarding.retry")
                .disabled(viewModel.isRefreshing)

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(viewModel.lastCheckedDescription(copy: copy))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .task(id: appModel.pairs.count) {
            await refresh()
        }
    }

    private func refresh() async {
        await viewModel.retry(pairCount: appModel.pairs.count)
        appModel.applyOnboardingState(viewModel.state, using: environment.statusService)
        appModel.refreshBackgroundState()
    }
}
