import SwiftUI
import ExochronometerCore

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                ScrollView {
                    VStack(spacing: 32) {
                        header

                        ForEach(TimeFrame.allCases) { frame in
                            TimeCircleView(timeFrame: frame, date: context.date)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                }
            }
        }
    }

    private var header: some View {
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
        .padding(.top, 16)
    }
}

#Preview {
    ContentView()
}
