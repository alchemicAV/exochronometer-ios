import SwiftUI
import WidgetKit
import ExochronometerCore

struct LargeChronometerWidget: Widget {
    let kind = "LargeChronometerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TimeframeConfigurationIntent.self,
            provider: ChronometerProvider()
        ) { entry in
            LargeChronometerView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Exochronometer")
        .description("Geometric time circle.")
        .supportedFamilies([.systemLarge])
    }
}

struct LargeChronometerView: View {
    let entry: ChronometerEntry

    var body: some View {
        let frame = entry.timeframe.timeFrame
        let degree = frame.degree(at: entry.date)

        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                .padding(20)

            GeometryReader { proxy in
                let radius = (min(proxy.size.width, proxy.size.height) - 40) / 2
                let radians = (degree - 90) * .pi / 180
                let x = proxy.size.width / 2 + radius * cos(radians)
                let y = proxy.size.height / 2 + radius * sin(radians)
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .position(x: x, y: y)
                    .shadow(color: .white.opacity(0.7), radius: 10)
            }

            VStack(spacing: 4) {
                Text(frame.label)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.85))
                Text(frame.sublabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                Text(frame.traditionalLabel(at: entry.date))
                    .font(.system(size: 20, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 8)
            }
        }
    }
}
