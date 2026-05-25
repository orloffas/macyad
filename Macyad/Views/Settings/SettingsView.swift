import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        let copy = appModel.copy

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

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420)
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
}
