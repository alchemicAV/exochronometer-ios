import SwiftUI
import ExochronometerCore

struct TimeCircleView: View {
    let timeFrame: TimeFrame
    let date: Date

    var body: some View {
        let degree = timeFrame.degree(at: date)

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
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 8)
        }
    }
}
