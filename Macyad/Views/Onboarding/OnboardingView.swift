import MacyadCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        let copy = appModel.copy

        let step = viewModel.displayStep(pairCount: appModel.pairs.count)

        return VStack(alignment: .leading, spacing: 16) {
            Text(step == .complete ? copy.onboardingEnvironmentTitle : copy.onboardingTitle)
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.lastCheckedAt == nil, viewModel.isRefreshing {
                // Before the first check lands, `state` still says "install
                // rclone". Showing that to someone who has rclone installed
                // reads as a failed detection, then flips a moment later.
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                switch step {
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
                        // Wrapping comes from the width limit below, not from
                        // fixedSize: asking a long string for its ideal height
                        // at unbounded width leaves this pane unable to lay out
                        // at all, and the whole window renders blank.
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // The version belongs on the pane people are told to open
                    // when something is wrong, next to the rclone version it
                    // is going to be quoted alongside.
                    LabeledContent(copy.appVersionLabel, value: AppMetadata.versionDisplay)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

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

                if step == .installRclone || step == .configureRemote {
                    // The user leaves for Terminal at this point; nothing checks
                    // the environment on their return any more, so say what to
                    // press when they come back.
                    Text(copy.onboardingRecheckAfterCommandHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                if viewModel.lastCheckFailed {
                    Label(copy.onboardingCheckFailed, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text(viewModel.lastCheckedDescription(copy: copy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(20)
        .task {
            // Only the first time the pane is shown. The check runs rclone, and
            // re-running it on every visit both surprises the user and makes the
            // "Re-check environment" button look decorative.
            guard viewModel.lastCheckedAt == nil else {
                return
            }

            await refresh()
        }
    }

    private func refresh() async {
        await viewModel.retry(pairCount: appModel.pairs.count)
        appModel.applyOnboardingState(viewModel.state, using: environment.statusService)
        appModel.refreshBackgroundState()
    }
}
