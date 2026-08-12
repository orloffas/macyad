import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        let copy = appModel.copy

        VStack(spacing: 0) {
            Form {
                Section {
                    Picker(copy.languageLabel, selection: languageBinding) {
                        Text(copy.englishLanguageName).tag("en")
                        Text(copy.russianLanguageName).tag("ru")
                    }

                    Toggle(copy.launchAtLoginLabel, isOn: launchAtLoginBinding)

                    Stepper(value: scheduleBinding, in: 5 ... 240, step: 5) {
                        Text(copy.defaultScheduleTitle(minutes: viewModel.defaultScheduleMinutes))
                    }
                }

                Section {
                    Toggle(copy.pauseAllSchedulesToggleTitle, isOn: globalSchedulerPausedBinding)
                } header: {
                    Text(copy.scheduledSyncSectionTitle)
                }

                Section {
                    LabeledContent(copy.notificationsStatusLabel, value: notificationStatusTitle)
                    HStack {
                        Button(copy.notificationsRequestButtonTitle) {
                            Task { await viewModel.requestNotificationPermission() }
                        }
                        Button(copy.notificationsSendTestButtonTitle) {
                            Task { await viewModel.sendTestNotification() }
                        }
                    }

                    if let lastNotificationAttempt = viewModel.lastNotificationAttempt {
                        LabeledContent(copy.notificationsLastAttemptLabel) {
                            Text(lastNotificationAttempt)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text(copy.notificationsSectionTitle)
                }

                Section {
                    if viewModel.accounts.isEmpty {
                        Text(copy.noAccountsHint)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.accounts) { account in
                            let removalState = viewModel.accountRemovalState(for: account, pairs: appModel.pairs)
                            VStack(alignment: .leading, spacing: 10) {
                                LabeledContent(copy.accountDisplayNameLabel, value: account.displayName)
                                LabeledContent(copy.accountRemoteNameLabel, value: account.remoteName)
                                LabeledContent(copy.accountConfigPathLabel, value: account.configPath)
                                    .textSelection(.enabled)

                                CommandCopyRowView(
                                    title: copy.reconnectAccountButtonTitle,
                                    command: viewModel.reconnectCommand(for: account),
                                    copied: viewModel.lastCopiedCommand == viewModel.reconnectCommand(for: account),
                                    accessibilityIdentifier: nil
                                ) {
                                    viewModel.copy(viewModel.reconnectCommand(for: account))
                                }

                                CommandCopyRowView(
                                    title: copy.recreateAccountButtonTitle,
                                    command: viewModel.recreateCommand(for: account),
                                    copied: viewModel.lastCopiedCommand == viewModel.recreateCommand(for: account),
                                    accessibilityIdentifier: nil
                                ) {
                                    viewModel.copy(viewModel.recreateCommand(for: account))
                                }

                                CommandCopyRowView(
                                    title: copy.removeAccountButtonTitle,
                                    command: viewModel.removeCommand(for: account),
                                    copied: viewModel.lastCopiedCommand == viewModel.removeCommand(for: account),
                                    accessibilityIdentifier: nil
                                ) {
                                    viewModel.copy(viewModel.removeCommand(for: account))
                                }

                                HStack {
                                    Spacer()
                                    Button(copy.removeAccountButtonTitle, role: .destructive) {
                                        Task { await viewModel.removeAccount(account, pairs: appModel.pairs) }
                                    }
                                    .disabled(!removalState.canRemove)
                                }

                                if let inlineMessage = removalState.inlineMessage {
                                    HStack {
                                        Spacer()
                                        Text(inlineMessage)
                                            .font(.footnote)
                                            .foregroundStyle(.orange)
                                            .multilineTextAlignment(.trailing)
                                            .frame(maxWidth: 300, alignment: .trailing)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                } header: {
                    Text(copy.accountsSectionTitle)
                } footer: {
                    Text(copy.accountRemoteNameHint)
                }

                Section {
                    TextField(copy.accountDisplayNameLabel, text: addAccountNameBinding)
                    TextField(copy.accountRemoteNameLabel, text: addAccountRemoteBinding)

                    HStack {
                        Spacer()
                        Button(copy.addAccountButtonTitle) {
                            Task { await viewModel.addAccount() }
                        }
                    }
                } header: {
                    Text(copy.addAccountButtonTitle)
                } footer: {
                    Text(copy.onboardingAccountsHint)
                }

                Section {
                    HStack {
                        Button(copy.exportConfigurationButtonTitle) {
                            Task { await viewModel.exportConfiguration(pairs: appModel.pairs) }
                        }
                        .accessibilityIdentifier("configuration.export")
                        Button(copy.importConfigurationButtonTitle) {
                            Task { await viewModel.prepareConfigurationImport() }
                        }
                        .accessibilityIdentifier("configuration.import")
                        Spacer()
                    }
                } header: {
                    Text(copy.configurationSectionTitle)
                } footer: {
                    Text(copy.configurationExportHint)
                }

                Section {
                    LabeledContent(copy.appVersionLabel, value: AppMetadata.versionDisplay)

                    Text(copy.aboutCopyright(year: AppMetadata.copyrightYear))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Link(copy.aboutRepositoryLinkTitle, destination: AppMetadata.repositoryURL)
                        Link(copy.aboutReleasesLinkTitle, destination: AppMetadata.releasesURL)
                        Link(copy.aboutReportIssueLinkTitle, destination: AppMetadata.newIssueURL)
                        Spacer()
                    }
                    .font(.callout)

                    HStack {
                        Button(copy.copyDiagnosticsButtonTitle) {
                            viewModel.copyDiagnostics(
                                appVersion: AppMetadata.versionDisplay,
                                onboardingState: appModel.onboardingState,
                                pairCount: appModel.pairs.count,
                                copy: copy
                            )
                        }
                        .accessibilityIdentifier("diagnostics.copy")
                        Spacer()
                    }

                    Text(copy.aboutRcloneCredit)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text(copy.aboutSectionTitle)
                } footer: {
                    Text(copy.copyDiagnosticsHint)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let errorMessage = viewModel.errorMessage {
                Divider()
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 760)
        .background(
            WindowAccessor { window in
                window.title = copy.settingsWindowTitle
            }
        )
        .alert(
            copy.configurationImportConfirmTitle,
            isPresented: Binding(
                get: { viewModel.pendingImportPlan != nil },
                set: { if !$0 { viewModel.cancelConfigurationImport() } }
            ),
            presenting: viewModel.pendingImportPlan
        ) { plan in
            Button(copy.configurationImportConfirmButtonTitle, role: .destructive) {
                Task { await viewModel.applyPendingConfigurationImport() }
            }
            Button(copy.cancelButtonTitle, role: .cancel) {
                viewModel.cancelConfigurationImport()
            }
        } message: { plan in
            Text(copy.configurationImportConfirmMessage(pairs: plan.pairs.count, accounts: plan.accounts.count))
        }
        .alert(
            copy.configurationImportDoneTitle,
            isPresented: Binding(
                get: { viewModel.importSummary != nil },
                set: { if !$0 { viewModel.dismissImportSummary() } }
            )
        ) {
            Button(copy.closeButtonTitle) { viewModel.dismissImportSummary() }
        } message: {
            Text(importResultMessage)
        }
        .alert(
            copy.restartPromptTitle,
            isPresented: restartPromptBinding,
            actions: {
                Button(copy.restartNowButtonTitle) {
                    ApplicationRelauncher.relaunch()
                }

                Button(copy.laterButtonTitle, role: .cancel) {
                    viewModel.dismissRestartPrompt()
                }
            },
            message: {
                Text(copy.restartPromptMessage)
            }
        )
        .task {
            await viewModel.loadIfNeeded()
        }
        .onReceive(viewModel.$accounts) { accounts in
            appModel.accounts = accounts
        }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedLanguage },
            set: { viewModel.updateSelectedLanguage($0) }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { viewModel.launchAtLogin },
            set: { newValue in
                Task { await viewModel.updateLaunchAtLogin(newValue) }
            }
        )
    }

    private var scheduleBinding: Binding<Int> {
        Binding(
            get: { viewModel.defaultScheduleMinutes },
            set: { viewModel.updateDefaultScheduleMinutes($0) }
        )
    }

    private var restartPromptBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isRestartPromptPresented },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissRestartPrompt()
                }
            }
        )
    }

    private var addAccountNameBinding: Binding<String> {
        Binding(
            get: { viewModel.newAccountDisplayName },
            set: { viewModel.updateNewAccountDisplayName($0) }
        )
    }

    private var addAccountRemoteBinding: Binding<String> {
        Binding(
            get: { viewModel.newAccountRemoteName },
            set: { viewModel.newAccountRemoteName = $0 }
        )
    }

    private var globalSchedulerPausedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isGlobalSchedulerPaused },
            set: { viewModel.updateIsGlobalSchedulerPaused($0) }
        )
    }

    /// The summary, plus anything the import could not carry over. Issues are
    /// part of the same alert rather than a separate screen: with a handful of
    /// pairs a list of two or three lines says everything a preview table
    /// would have said.
    private var importResultMessage: String {
        let copy = appModel.copy
        guard !viewModel.importIssues.isEmpty else {
            return viewModel.importSummary ?? ""
        }

        // An alert body does not scroll, and a folder path wraps onto two
        // lines: past a few issues the list stops being readable, so the tail
        // is counted instead of listed. The pairs themselves carry the same
        // information in the pair list.
        let shown = viewModel.importIssues.prefix(3).map { "• \($0)" }
        let remainder = viewModel.importIssues.count - shown.count
        let tail = remainder > 0 ? [copy.configurationImportMoreIssues(count: remainder)] : []

        return ([viewModel.importSummary ?? "", "", copy.configurationImportIssuesTitle] + shown + tail)
            .joined(separator: "\n")
    }

    private var notificationStatusTitle: String {
        let copy = appModel.copy
        return switch viewModel.notificationStatus {
        case .authorized:
            copy.notificationsStatusAuthorized
        case .denied:
            copy.notificationsStatusDenied
        case .notDetermined:
            copy.notificationsStatusNotDetermined
        case .provisional:
            copy.notificationsStatusProvisional
        case .ephemeral:
            copy.notificationsStatusEphemeral
        case .unknown:
            copy.notificationsStatusUnknown
        }
    }
}
