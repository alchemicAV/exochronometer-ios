import SwiftUI
import SwiftData
import ExochronometerCore

struct ContentView: View {
    @Query(sort: \JournalNote.timestamp, order: .reverse) private var notes: [JournalNote]
    @State private var showTimeline = false

    var body: some View {
        let snapshots = notes.map(\.snapshot)
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.noteID, $0) })
        let lookup: (UUID) -> JournalNote? = { byID[$0] }

        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                ScrollView {
                    VStack(spacing: 32) {
                        header

                        ForEach(TimeFrame.allCases) { frame in
                            TimeCircleView(
                                timeFrame: frame,
                                date: context.date,
                                noteSnapshots: snapshots,
                                noteLookup: lookup
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }

            JournalInput()
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .sheet(isPresented: $showTimeline) {
            TimelineSheet()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Spacer()
                .overlay(alignment: .trailing) {
                    Color.clear.frame(width: 36, height: 36)
                }
            VStack(spacing: 4) {
                Text("EXOCHRONOMETER")
                    .font(.system(size: 14, weight: .light, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(.white.opacity(0.7))
                Text("JOURNAL")
                    .font(.system(size: 9, weight: .light, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
                .overlay(alignment: .leading) {
                    Button {
                        showTimeline = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                }
        }
        .padding(.top, 16)
    }
}
