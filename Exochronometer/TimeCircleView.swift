import SwiftUI
import ExochronometerCore

struct TimeCircleView: View {
    let timeFrame: TimeFrame
    let date: Date

    var body: some View {
        let degree = timeFrame.degree(at: date)

        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            GeometryReader { proxy in
                let radius = min(proxy.size.width, proxy.size.height) / 2
                let radians = (degree - 90) * .pi / 180
                let x = proxy.size.width / 2 + radius * cos(radians)
                let y = proxy.size.height / 2 + radius * sin(radians)
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .position(x: x, y: y)
                    .shadow(color: .white.opacity(0.6), radius: 8)
            }

            VStack(spacing: 4) {
                Text(timeFrame.label)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.85))
                Text(timeFrame.sublabel)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Text(timeFrame.traditionalLabel(at: date))
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
