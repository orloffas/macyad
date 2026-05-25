import MacyadCore
import SwiftUI

struct CreatePairSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var viewModel: CreatePairViewModel
    let onSave: @MainActor (SyncPair) async throws -> Void

    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        let copy = appModel.copy

        VStack(alignment: .leading, spacing: 14) {
            Text(copy.createPairTitle)
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                TextField(copy.pairNamePlaceholder, text: $viewModel.name)

                HStack {
                    Text(viewModel.localFolderDisplayPath ?? copy.localFolderNotSelected)
                        .foregroundStyle(viewModel.localFolderDisplayPath == nil ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    Button(copy.chooseFolderButtonTitle) {
                        viewModel.chooseFolder()
                    }
                }

                TextField(copy.remotePathPlaceholder, text: $viewModel.remotePath)

                Stepper(copy.intervalTitle(minutes: viewModel.scheduleMinutes), value: $viewModel.scheduleMinutes, in: 5...240, step: 5)

                Picker(copy.deletePolicyLabel, selection: $viewModel.deletePolicy) {
                    Text(copy.deletePolicyMirrorTitle).tag(SyncPair.DeletePolicy.mirrorToYandex)
                    Text(copy.deletePolicyManualTitle).tag(SyncPair.DeletePolicy.keepRemoteDeletesManual)
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

                Button(copy.cancelButtonTitle) {
                    dismiss()
                }

                Button(copy.savePairButtonTitle) {
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
        let copy = appModel.copy
        let folder = viewModel.localFolderDisplayPath ?? copy.localFolderNotSelectedCompact
        return copy.createPairSummary(
            folder: folder,
            remotePath: viewModel.remotePath,
            scheduleMinutes: viewModel.scheduleMinutes
        )
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
