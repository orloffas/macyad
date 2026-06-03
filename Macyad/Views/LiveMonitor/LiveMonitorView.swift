import SwiftUI
import MacyadCore

struct LiveMonitorView: View {
    @ObservedObject var viewModel: LiveMonitorViewModel
    let copy: AppCopy

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.lines.indices, id: \.self) { index in
                            Text(viewModel.lines[index])
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .id(index)
                        }
                    }
                    .textSelection(.enabled)
                }
                .onChange(of: viewModel.lines.count) { _, _ in
                    if let last = viewModel.lines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack {
                switch viewModel.exitStatus {
                case .none:
                    Text(copy.liveMonitorRunningFooter)
                        .foregroundStyle(.secondary)
                case .success:
                    Text(copy.liveMonitorExitedSuccessFooter)
                        .foregroundStyle(.green)
                case .failed(let code):
                    Text(copy.liveMonitorExitedFailedFooter(code: code))
                        .foregroundStyle(.red)
                }
                Spacer()
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}
