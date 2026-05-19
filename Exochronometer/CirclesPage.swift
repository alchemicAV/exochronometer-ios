import SwiftUI
import SwiftData
import ExochronometerCore

struct CirclesPage: View {
    @Query(sort: \JournalNote.timestamp, order: .reverse) private var notes: [JournalNote]

    var body: some View {
        let snapshots = notes.map(\.snapshot)
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.noteID, $0) })
        let lookup: (UUID) -> JournalNote? = { byID[$0] }

        ZStack(alignment: .bottom) {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                ScrollView {
                    VStack(spacing: 32) {
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
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }

            JournalInput()
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
    }
}
