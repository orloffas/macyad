import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                Picker("settings.language", selection: languageBinding) {
                    Text("Русский").tag("ru")
                    Text("English").tag("en")
                }

                Toggle("settings.launchAtLogin", isOn: launchAtLoginBinding)

                Stepper(value: scheduleBinding, in: 5 ... 240, step: 5) {
                    Text(scheduleTitle)
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

    private var scheduleTitle: String {
        String(
            format: String(localized: "settings.defaultScheduleFormat"),
            viewModel.defaultScheduleMinutes
        )
    }
}
