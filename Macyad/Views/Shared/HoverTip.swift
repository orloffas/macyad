import SwiftUI

/// SwiftUI `.help` uses the system tooltip delay (≈1.5 s) which feels sluggish
/// for inline status affordances. This modifier shows a lightweight popover
/// after a short hover delay (default 0.4 s) and works on disabled controls.
struct HoverTipModifier: ViewModifier {
    let text: String
    let delay: Double

    @State private var isHovering = false
    @State private var isVisible = false
    @State private var pendingTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                pendingTask?.cancel()
                isHovering = hovering
                if hovering {
                    let delaySeconds = delay
                    pendingTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                        if Task.isCancelled { return }
                        await MainActor.run { isVisible = true }
                    }
                } else {
                    isVisible = false
                }
            }
            .popover(isPresented: $isVisible, arrowEdge: .bottom) {
                // A popover proposes its whole container to the content, and
                // `maxWidth` accepts that proposal for the height — which is how
                // a two-line tip grew into a window-tall empty panel. A fixed
                // width plus `fixedSize` vertically asks for the wrapped text's
                // own height instead.
                Text(text)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(width: 280, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
    }
}

extension View {
    /// Shows `text` as a small popover tooltip after a brief hover delay,
    /// bypassing the slow system `.help` delay. Pass an empty string to no-op.
    func hoverTip(_ text: String, delay: Double = 0.4) -> some View {
        Group {
            if text.isEmpty {
                self
            } else {
                self.modifier(HoverTipModifier(text: text, delay: delay))
            }
        }
    }
}
