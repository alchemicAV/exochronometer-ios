import SwiftUI
import WidgetKit
import ExochronometerCore

struct LockScreenChronometerWidget: Widget {
    let kind = "LockScreenChronometerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TimeframeConfigurationIntent.self,
            provider: ChronometerProvider()
        ) { entry in
            LockScreenChronometerView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Exochronometer")
        .description("Geometric time circle for the lock screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LockScreenChronometerView: View {
    let entry: ChronometerEntry

    var body: some View {
        let frame = entry.timeframe.timeFrame
        let degree = frame.degree(at: entry.date)

        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .stroke(.white.opacity(0.5), lineWidth: 1)
                .padding(4)

            GeometryReader { proxy in
                let radius = (min(proxy.size.width, proxy.size.height) - 8) / 2
                let radians = (degree - 90) * .pi / 180
                let x = proxy.size.width / 2 + radius * cos(radians)
                let y = proxy.size.height / 2 + radius * sin(radians)
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
        }
        .widgetAccentable()
    }
}
