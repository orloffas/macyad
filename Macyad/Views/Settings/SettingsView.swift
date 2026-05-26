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
