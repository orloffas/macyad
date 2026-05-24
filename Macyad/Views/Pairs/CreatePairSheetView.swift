import MacyadCore
import SwiftUI

struct CreatePairSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePairViewModel
    let onSave: @MainActor (SyncPair) async throws -> Void

    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Новая pair")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                TextField("Имя pair", text: $viewModel.name)

                HStack {
                    Text(viewModel.localFolderDisplayPath ?? "Локальная папка не выбрана")
                        .foregroundStyle(viewModel.localFolderDisplayPath == nil ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    Button("Выбрать папку") {
                        viewModel.chooseFolder()
                    }
                }

                TextField("Remote path", text: $viewModel.remotePath)

                Stepper("Интервал: \(viewModel.scheduleMinutes) мин", value: $viewModel.scheduleMinutes, in: 5...240, step: 5)

                Picker("Delete policy", selection: $viewModel.deletePolicy) {
                    Text("Mirror to Yandex").tag(SyncPair.DeletePolicy.mirrorToYandex)
                    Text("Keep remote deletes manual").tag(SyncPair.DeletePolicy.keepRemoteDeletesManual)
                }

                Section {
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Отмена") {
                    dismiss()
                }

                Button("Сохранить pair") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving || !viewModel.canSave)
            }
        }
        .padding(18)
        .frame(width: 560)
    }

    private var summaryText: String {
        let folder = viewModel.localFolderDisplayPath ?? "не выбрана"
        return "Будет синхронизация \(folder) -> \(viewModel.remotePath) каждые \(viewModel.scheduleMinutes) мин."
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let pair = try viewModel.buildPair()
            try await onSave(pair)
            dismiss()
        } catch let error as PairService.ValidationError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
