import SwiftUI
import SwiftData
import ExochronometerCore

struct JournalInput: View {
    @Environment(\.modelContext) private var ctx
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField(
                "",
                text: $text,
                prompt: Text("JOURNAL")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.white)
            .tint(.white)
            .submitLabel(.send)
            .focused($focused)
            .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(text.isEmpty ? 0.25 : 0.8))
            }
            .disabled(text.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 0.5))
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        var dict: [String: Double] = [:]
        for frame in TimeFrame.allCases {
            dict[frame.rawValue] = frame.degree(at: now)
        }
        ctx.insert(JournalNote(timestamp: now, text: trimmed, degrees: dict))
        text = ""
    }
}
