import SwiftUI
import SwiftData

struct TimelineSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimelineView()
                .navigationTitle("TIMELINE")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
                .toolbarBackground(.black, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

private struct TimelineView: View {
    @Query(sort: \JournalNote.timestamp, order: .forward) private var notes: [JournalNote]

    @State private var zoomIdx: Int = 2
    private let zoomLevels: [Double] = [0.25, 0.5, 1, 2, 4, 8]
    private var zoom: Double { zoomLevels[zoomIdx] }

    private let pxPerHour: Double = 12
    private let minGap: Double = 60
    private let flagHeights: [Double] = [36, 60, 84]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if notes.isEmpty {
                Text("NO NOTES")
                    .font(.system(size: 12, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                trackScroll
            }

            VStack {
                Spacer()
                zoomBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    private var trackScroll: some View {
        let items = layoutItems()
        let totalWidth = (items.last?.x ?? 60) + 200

        return ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(.white.opacity(0.5))
                    .frame(width: totalWidth, height: 1)
                    .padding(.bottom, 30)

                ForEach(items) { item in
                    TimelineFlag(item: item)
                        .offset(x: item.x, y: 0)
                        .padding(.bottom, 30)
                }
            }
            .frame(width: max(totalWidth, 320), height: 220, alignment: .bottomLeading)
        }
        .padding(.top, 20)
    }

    private var zoomBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 10) {
                Button(action: zoomOut) {
                    Text("−")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(.white.opacity(0.4), lineWidth: 0.5)
                        )
                }
                .disabled(zoomIdx == 0)
                .opacity(zoomIdx == 0 ? 0.25 : 1)

                Text(zoomLabel)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(minWidth: 36)

                Button(action: zoomIn) {
                    Text("+")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(.white.opacity(0.4), lineWidth: 0.5)
                        )
                }
                .disabled(zoomIdx == zoomLevels.count - 1)
                .opacity(zoomIdx == zoomLevels.count - 1 ? 0.25 : 1)
            }
        }
    }

    private var zoomLabel: String {
        if zoom < 1 {
            return "\(zoom)x"
        }
        return "\(Int(zoom))x"
    }

    private func zoomIn() { zoomIdx = min(zoomIdx + 1, zoomLevels.count - 1) }
    private func zoomOut() { zoomIdx = max(zoomIdx - 1, 0) }

    private func layoutItems() -> [LayoutItem] {
        guard !notes.isEmpty else { return [] }
        let secondsPerHour: Double = 3600

        if notes.count == 1 {
            let only = notes[0]
            return [LayoutItem(
                id: only.noteID,
                x: 60,
                flagHeight: flagHeights[1],
                text: only.text,
                timestamp: only.timestamp
            )]
        }

        var gaps: [Double] = []
        for i in 1..<notes.count {
            gaps.append(notes[i].timestamp.timeIntervalSince(notes[i - 1].timestamp))
        }
        let pixelGaps = gaps.map { g -> Double in
            let hours = g / secondsPerHour
            return max(minGap, hours * pxPerHour) * zoom
        }

        var items: [LayoutItem] = []
        var heightIdxs: [Int] = []
        var x: Double = 60
        for (i, note) in notes.enumerated() {
            var heightIdx = i % flagHeights.count
            if i > 0 {
                let prevGap = pixelGaps[i - 1]
                let prevHeightIdx = heightIdxs[i - 1]
                if prevGap < 100 * zoom && heightIdx == prevHeightIdx {
                    heightIdx = (heightIdx + 1) % flagHeights.count
                }
            }
            items.append(LayoutItem(
                id: note.noteID,
                x: x,
                flagHeight: flagHeights[heightIdx],
                text: note.text,
                timestamp: note.timestamp
            ))
            heightIdxs.append(heightIdx)
            if i < notes.count - 1 {
                x += pixelGaps[i]
            }
        }
        return items
    }
}

private struct LayoutItem: Identifiable {
    let id: UUID
    let x: Double
    let flagHeight: Double
    let text: String
    let timestamp: Date
}

private struct TimelineFlag: View {
    let item: LayoutItem

    private static let monthNames = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(.white.opacity(0.5))
                .frame(width: 1, height: item.flagHeight)

            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
                .offset(x: -3, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(dateString)
                    .font(.system(size: 8, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.35))
                Text(timeString)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Text(item.text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .fixedSize()
            .offset(x: 6, y: -(item.flagHeight + 4))
        }
        .frame(width: 1, height: item.flagHeight, alignment: .bottom)
    }

    private var dateString: String {
        let comps = Calendar.current.dateComponents([.month, .day], from: item.timestamp)
        let m = max(1, min(12, comps.month ?? 1)) - 1
        return "\(Self.monthNames[m]) \(comps.day ?? 0)"
    }

    private var timeString: String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: item.timestamp)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }
}
