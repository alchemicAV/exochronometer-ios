import SwiftUI
import ExochronometerCore

struct TimeCircleView: View {
    let timeFrame: TimeFrame
    let date: Date
    let noteSnapshots: [NoteSnapshot]
    let noteLookup: (UUID) -> JournalNote?

    @State private var selectedNode: NoteSnap.Node?

    var body: some View {
        let degree = timeFrame.degree(at: date)
        let snappedNodes = NoteSnap.snap(notes: noteSnapshots, circle: timeFrame)

        VStack(spacing: 6) {
            Text(timeFrame.label)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.85))
            Text(timeFrame.sublabel)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)

                GeometryOverlayView(currentDegree: degree, lineWidth: 0.6)

                GeometryReader { proxy in
                    let radius = min(proxy.size.width, proxy.size.height) / 2
                    let cx = proxy.size.width / 2
                    let cy = proxy.size.height / 2

                    ForEach(snappedNodes) { node in
                        let nodeOp = NoteSnap.nodeOpacity(
                            nodeDegree: node.degree,
                            currentDegree: degree
                        )
                        if nodeOp > 0.001 {
                            let radians = (node.degree - 90) * .pi / 180
                            NoteIndicator(opacity: nodeOp, count: node.noteIDs.count)
                                .position(
                                    x: cx + radius * cos(radians),
                                    y: cy + radius * sin(radians)
                                )
                                .onTapGesture {
                                    selectedNode = node
                                }
                        }
                    }
                }

                GeometryReader { proxy in
                    let radius = min(proxy.size.width, proxy.size.height) / 2
                    let radians = (degree - 90) * .pi / 180
                    let x = proxy.size.width / 2 + radius * cos(radians)
                    let y = proxy.size.height / 2 + radius * sin(radians)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                        .shadow(color: .white.opacity(0.6), radius: 6)
                }

                Text(timeFrame.traditionalLabel(at: date))
                    .font(.system(size: 14, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                if let node = selectedNode {
                    let resolved = node.noteIDs.compactMap(noteLookup)
                    if !resolved.isEmpty {
                        NotePanel(notes: resolved) {
                            selectedNode = nil
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 8)
        }
        .animation(.easeInOut(duration: 0.15), value: selectedNode?.id)
    }
}
