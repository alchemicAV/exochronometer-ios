import SwiftUI
import ExochronometerCore

enum SpatialMode: String, CaseIterable, Identifiable {
    case chladni
    case spectrogram
    case lissajous
    case convergence

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chladni:      return "CHLADNI"
        case .spectrogram:  return "SPECTROGRAM"
        case .lissajous:    return "LISSAJOUS"
        case .convergence:  return "CONVERGENCE"
        }
    }

    var subtitle: String {
        switch self {
        case .chladni:     return "2D membrane modes summed by amplitude"
        case .spectrogram: return "linear · quarter-moon window · refreshes every 10s"
        case .lissajous:   return "within-timeframe pairs · sectioned fast → slow"
        case .convergence: return "time until next angular alignment (live)"
        }
    }
}

struct SpatialAnalysisPage: View {
    @State private var mode: SpatialMode = .chladni

    var body: some View {
        VStack(spacing: 10) {
            header

            modePicker
                .padding(.horizontal, 16)

            Group {
                switch mode {
                case .lissajous:   LissajousView()
                case .spectrogram: SpectrogramView()
                case .chladni:     ChladniView()
                case .convergence: ConvergenceView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SPATIAL ANALYSIS")
                .font(.system(size: 10, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.6))
            Text(mode.subtitle)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SpatialMode.allCases) { m in
                    Button {
                        mode = m
                    } label: {
                        Text(m.label)
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(mode == m ? .black : .white.opacity(0.7))
                            .background(
                                Capsule().fill(mode == m ? Color.white : .clear)
                            )
                            .overlay(
                                Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Lissajous (sectioned by timeframe, fast → slow)

private func gcd(_ a: Int, _ b: Int) -> Int {
    var x = abs(a)
    var y = abs(b)
    while y != 0 {
        (x, y) = (y, x % y)
    }
    return x
}

private struct LissajousPair: Identifiable {
    let a: HarmonicTone
    let b: HarmonicTone
    var id: String { "\(a.id)-vs-\(b.id)" }
}

private struct LissajousView: View {
    private let scaling: Int = 23
    private let orderedTimeframes: [TimeFrame] = [.hour, .day, .quarterMoon, .moon, .year]

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: false)) { context in
            let pairsByTF = pairsByTimeframe(at: context.date)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(orderedTimeframes, id: \.self) { tf in
                        LissajousSection(
                            timeframe: tf,
                            pairs: pairsByTF[tf] ?? []
                        )
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private func pairsByTimeframe(at date: Date) -> [TimeFrame: [LissajousPair]] {
        let tones = HarmonicAnalysis.activeTones(at: date, scales: [scaling])
        let grouped = Dictionary(grouping: tones, by: { $0.timeframe })
        var result: [TimeFrame: [LissajousPair]] = [:]
        for tf in orderedTimeframes {
            let group = grouped[tf] ?? []
            guard group.count >= 2 else {
                result[tf] = []
                continue
            }
            var pairs: [LissajousPair] = []
            for i in 0..<group.count {
                for j in (i + 1)..<group.count {
                    pairs.append(LissajousPair(a: group[i], b: group[j]))
                }
            }
            result[tf] = pairs
        }
        return result
    }
}

private struct LissajousSection: View {
    let timeframe: TimeFrame
    let pairs: [LissajousPair]

    private static let placeholderHeight: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerLabel)
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))

            if pairs.isEmpty {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
                    .frame(height: Self.placeholderHeight)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(pairs) { pair in
                        LissajousCell(pair: pair)
                    }
                }
            }
        }
    }

    private var headerLabel: String {
        switch timeframe {
        case .year:        return "YEAR"
        case .moon:        return "MOON CYCLE"
        case .quarterMoon: return "1/4 MOON"
        case .day:         return "ONE DAY"
        case .hour:        return "ONE HOUR"
        case .minute:      return "ONE MINUTE"
        }
    }
}

private struct LissajousCell: View {
    let pair: LissajousPair

    var body: some View {
        VStack(spacing: 4) {
            Canvas { ctx, size in
                drawCurve(in: &ctx, size: size)
            }
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )

            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var label: String {
        let aDiv = pair.a.divisions
        let bDiv = pair.b.divisions
        let g = gcd(aDiv, bDiv)
        return "\(aDiv / g):\(bDiv / g)"
    }

    private func drawCurve(in ctx: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(size.width, size.height) / 2 - 4

        let aDiv = pair.a.divisions
        let bDiv = pair.b.divisions
        let g = gcd(aDiv, bDiv)
        let m = aDiv / g
        let n = bDiv / g

        let samples = 800
        var path = Path()
        for i in 0...samples {
            let theta = Double(i) / Double(samples) * 2 * .pi
            let x = cx + CGFloat(sin(Double(m) * theta)) * r
            let y = cy + CGFloat(sin(Double(n) * theta)) * r
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else      { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        let amp = pair.a.amplitude * pair.b.amplitude
        let opacity = pair.a.isFundamental && pair.b.isFundamental ? 0.85 : (0.4 + 0.5 * amp)
        ctx.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 0.7)
    }
}

// MARK: - Spectrogram (linear, quarter-moon window)

private final class SpectrogramBuffer: ObservableObject {
    @Published private(set) var frames: [Frame] = []
    private(set) var maxAge: TimeInterval = 60

    struct Frame: Identifiable {
        let id: Date
        let tones: [HarmonicTone]
    }

    /// Linearly spaced samples across the full window.
    func prePopulate(now: Date, scales: [Int], maxAge: TimeInterval, samples: Int = 400) {
        self.maxAge = maxAge
        var built: [Frame] = []
        let denom = max(1, samples - 1)
        let step = maxAge / Double(denom)
        for i in 0..<samples {
            let age = Double(i) * step
            let t = now.addingTimeInterval(-age)
            let tones = HarmonicAnalysis.activeTones(at: t, scales: scales)
            built.append(Frame(id: t, tones: tones))
        }
        frames = built.reversed()
    }
}

private struct SpectrogramView: View {
    @StateObject private var buffer = SpectrogramBuffer()
    @AppStorage("globalFundamentalsOff") private var fundamentalsOff: Bool = true

    private let scaling: Int = 23
    private let minFreqHz: Double = 0.1
    private let maxFreqHz: Double = 50_000
    /// Quarter-moon window (~7.38 days) — short enough for hour-cycle
    /// activity to read but long enough to span multiple day cycles.
    private let windowSeconds: TimeInterval = 637_860

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 0.5, paused: false)) { context in
            Canvas { ctx, size in
                drawScope(in: &ctx, size: size, now: context.date)
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
        .task(id: "spectrogram-refresh") {
            buffer.prePopulate(now: Date(), scales: [scaling], maxAge: windowSeconds)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { break }
                buffer.prePopulate(now: Date(), scales: [scaling], maxAge: windowSeconds)
            }
        }
    }

    private func drawScope(in ctx: inout GraphicsContext, size: CGSize, now: Date) {
        let logMinHz = log10(minFreqHz)
        let logMaxHz = log10(maxFreqHz)
        let hzRange = logMaxHz - logMinHz
        guard hzRange > 0 else { return }

        let axisWidth: CGFloat = 30
        let plotX = axisWidth
        let plotWidth = size.width - axisWidth

        for d in [0.1, 1.0, 10.0, 100.0, 1_000.0, 10_000.0] {
            let y = mapY(d, logMin: logMinHz, range: hzRange, height: size.height)
            let text = Text(decadeLabel(d))
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            ctx.draw(text, at: CGPoint(x: axisWidth / 2, y: y), anchor: .center)
        }
        var spine = Path()
        spine.move(to: CGPoint(x: plotX, y: 0))
        spine.addLine(to: CGPoint(x: plotX, y: size.height))
        ctx.stroke(spine, with: .color(.white.opacity(0.2)), lineWidth: 0.5)

        for frame in buffer.frames {
            let age = now.timeIntervalSince(frame.id)
            if age < 0 || age > windowSeconds { continue }
            let xFrac = 1.0 - age / windowSeconds
            let x = plotX + CGFloat(xFrac) * plotWidth

            for tone in frame.tones {
                guard tone.frequency >= minFreqHz, tone.frequency <= maxFreqHz else { continue }
                if fundamentalsOff && tone.isFundamental { continue }
                let y = mapY(tone.frequency, logMin: logMinHz, range: hzRange, height: size.height)
                let dotR: CGFloat = tone.isFundamental ? 1.4 : 1.1
                let alpha = tone.isFundamental ? 0.5 : tone.amplitude * 0.85
                let dot = CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)
                ctx.fill(Path(ellipseIn: dot), with: .color(.white.opacity(alpha)))
            }
        }

        var cursor = Path()
        cursor.move(to: CGPoint(x: size.width - 1, y: 0))
        cursor.addLine(to: CGPoint(x: size.width - 1, y: size.height))
        ctx.stroke(cursor, with: .color(.white.opacity(0.4)), lineWidth: 0.5)

        let day: Double = 86_400
        let timeMarkers: [(Double, String)] = [
            (0, "now"),
            (day, "1d"),
            (2 * day, "2d"),
            (3 * day, "3d"),
            (4 * day, "4d"),
            (5 * day, "5d"),
            (6 * day, "6d"),
            (7 * day, "7d"),
        ]
        for (age, label) in timeMarkers {
            if age > windowSeconds + 1 { continue }
            let xFrac = 1.0 - age / windowSeconds
            let x = plotX + CGFloat(xFrac) * plotWidth
            let text = Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            ctx.draw(text, at: CGPoint(x: x, y: size.height - 6), anchor: .center)
        }
    }

    private func mapY(_ freq: Double, logMin: Double, range: Double, height: CGFloat) -> CGFloat {
        let frac = (log10(freq) - logMin) / range
        return height * (1.0 - CGFloat(frac))
    }

    private func decadeLabel(_ value: Double) -> String {
        if value >= 1_000 { return "\(Int(value / 1_000))k" }
        if value >= 1     { return "\(Int(value))" }
        return String(format: "%g", value)
    }
}

// MARK: - Chladni

private struct ChladniView: View {
    @AppStorage("globalFundamentalsOff") private var fundamentalsOff: Bool = true
    private let scaling: Int = 23

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { context in
            let all = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let tones = fundamentalsOff ? all.filter { !$0.isFundamental } : all

            Canvas { ctx, size in
                drawPlate(in: &ctx, size: size, tones: tones)
            }
            .background(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    private func drawPlate(in ctx: inout GraphicsContext, size: CGSize, tones: [HarmonicTone]) {
        let side = min(size.width, size.height)
        let originX = (size.width - side) / 2
        let originY = (size.height - side) / 2
        let pixelStep: CGFloat = 4

        let cells = Int(side / pixelStep)
        guard cells > 0 else { return }

        let assignedModes: [(m: Int, n: Int, amp: Double)] = tones.map { tone in
            let m = modeIndex(for: tone.timeframe)
            let n = tone.divisions
            return (m: m, n: n, amp: tone.amplitude)
        }

        var maxAbs: Double = 0
        var grid: [[Double]] = Array(repeating: Array(repeating: 0, count: cells), count: cells)
        for row in 0..<cells {
            let y = Double(row) / Double(cells - 1)
            for col in 0..<cells {
                let x = Double(col) / Double(cells - 1)
                var u: Double = 0
                for mode in assignedModes {
                    if mode.amp < 0.01 { continue }
                    u += mode.amp * sin(Double(mode.m) * .pi * x) * sin(Double(mode.n) * .pi * y)
                }
                grid[row][col] = u
                let a = abs(u)
                if a > maxAbs { maxAbs = a }
            }
        }

        guard maxAbs > 0 else { return }

        for row in 0..<cells {
            for col in 0..<cells {
                let u = grid[row][col]
                let intensity = abs(u) / maxAbs
                let alpha = pow(intensity, 0.6)
                let cellRect = CGRect(
                    x: originX + CGFloat(col) * pixelStep,
                    y: originY + CGFloat(row) * pixelStep,
                    width: pixelStep,
                    height: pixelStep
                )
                ctx.fill(Path(cellRect), with: .color(.white.opacity(alpha * 0.9)))
            }
        }
    }

    private func modeIndex(for tf: TimeFrame) -> Int {
        switch tf {
        case .year:        return 1
        case .moon:        return 2
        case .quarterMoon: return 3
        case .day:         return 4
        case .hour:        return 5
        case .minute:      return 6
        }
    }
}

// MARK: - Convergence

private struct ConvergenceEvent: Identifiable {
    let id: String
    let label: String
    let secondsAway: TimeInterval
    let detail: String?

    init(id: String, label: String, secondsAway: TimeInterval, detail: String? = nil) {
        self.id = id
        self.label = label
        self.secondsAway = secondsAway
        self.detail = detail
    }
}

private struct ConvergenceView: View {
    private let timeframes: [TimeFrame] = TimeFrame.allCases.filter { $0 != .minute }

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("NEXT 0° ZERO-CROSSINGS")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))

                    ForEach(zeroCrossings(now: now)) { event in
                        eventRow(event)
                    }

                    Text("NEXT PAIR ALIGNMENTS")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 10)

                    ForEach(pairAlignments(now: now).sorted { $0.secondsAway < $1.secondsAway }) { event in
                        eventRow(event)
                    }

                    Text("NEXT CHORDS  ·  CROSS-TIMEFRAME")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.top, 10)

                    let chords = upcomingChords(now: now)
                    if chords.isEmpty {
                        Text("none in the next 24 hours")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    } else {
                        ForEach(chords) { event in
                            eventRow(event)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func eventRow(_ event: ConvergenceEvent) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(event.label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(formatDuration(event.secondsAway))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            if let detail = event.detail {
                Text(detail)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func zeroCrossings(now: Date) -> [ConvergenceEvent] {
        timeframes.map { tf in
            let degree = tf.degree(at: now)
            let positive = degree.truncatingRemainder(dividingBy: 360)
            let normalized = positive < 0 ? positive + 360 : positive
            let secondsRemaining = (360 - normalized) / 360 * tf.cycleDuration
            return ConvergenceEvent(
                id: "zero-\(tf.rawValue)",
                label: tf.label,
                secondsAway: secondsRemaining
            )
        }
    }

    private func pairAlignments(now: Date) -> [ConvergenceEvent] {
        var out: [ConvergenceEvent] = []
        for i in 0..<timeframes.count {
            for j in (i + 1)..<timeframes.count {
                let a = timeframes[i]
                let b = timeframes[j]
                if let seconds = secondsUntilAligned(a: a, b: b, now: now) {
                    out.append(ConvergenceEvent(
                        id: "align-\(a.rawValue)-\(b.rawValue)",
                        label: "\(a.label) ↔ \(b.label)",
                        secondsAway: seconds
                    ))
                }
            }
        }
        return out
    }

    private func secondsUntilAligned(a: TimeFrame, b: TimeFrame, now: Date) -> TimeInterval? {
        let rateA = 360.0 / a.cycleDuration
        let rateB = 360.0 / b.cycleDuration
        let relRate = rateA - rateB
        guard abs(relRate) > 1e-12 else { return nil }

        let degA = a.degree(at: now)
        let degB = b.degree(at: now)
        var diff = (degA - degB).truncatingRemainder(dividingBy: 360)
        if diff < 0 { diff += 360 }
        if diff < 1e-6 { return 360 / abs(relRate) }

        let distance: Double = relRate > 0 ? (360 - diff) : diff
        return distance / abs(relRate)
    }

    /// Recognized musical intervals, cents within one octave. Tolerance
    /// is applied separately. Just-intonation values.
    private static let chordIntervals: [(name: String, cents: Double)] = [
        ("Octave",            0),
        ("Perfect Fifth",     701.96),
        ("Perfect Fourth",    498.04),
        ("Major Third",       386.31),
        ("Minor Third",       315.64),
        ("Major Sixth",       884.36),
        ("Minor Sixth",       813.69),
        ("Harmonic Seventh",  968.83),
    ]

    /// Step forward 24 hours at 5-min intervals, detect cross-timeframe
    /// tone pairs whose ratio is within `tolerance` cents of a recognized
    /// interval. Emit one event per unique (toneA, toneB, interval) — the
    /// first time it occurs in the window.
    private func upcomingChords(now: Date) -> [ConvergenceEvent] {
        let horizonHours: Double = 24
        let stepMinutes: Double = 5
        let toleranceCents: Double = 25
        let steps = Int(horizonHours * 60 / stepMinutes)

        var events: [ConvergenceEvent] = []
        var seen: Set<String> = []

        for step in 0..<steps {
            let dt = Double(step) * stepMinutes * 60
            let t = now.addingTimeInterval(dt)
            let tones = HarmonicAnalysis.activeTones(at: t, scales: [23])
            guard tones.count >= 2 else { continue }

            for i in 0..<tones.count {
                for j in (i + 1)..<tones.count {
                    let a = tones[i]
                    let b = tones[j]
                    if a.timeframe == b.timeframe { continue }
                    if a.frequency <= 0 || b.frequency <= 0 { continue }

                    let low = min(a.frequency, b.frequency)
                    let high = max(a.frequency, b.frequency)
                    let cents = 1200 * log2(high / low)
                    let octaveCents = cents.truncatingRemainder(dividingBy: 1200)

                    for interval in Self.chordIntervals {
                        let distance = min(
                            abs(octaveCents - interval.cents),
                            abs(octaveCents - interval.cents - 1200),
                            abs(octaveCents - interval.cents + 1200)
                        )
                        if distance > toleranceCents { continue }

                        let key = "\(a.id)|\(b.id)|\(interval.name)"
                        if seen.contains(key) { continue }
                        seen.insert(key)

                        events.append(ConvergenceEvent(
                            id: key,
                            label: "\(interval.name)",
                            secondsAway: dt,
                            detail: "\(toneLabel(a))  +  \(toneLabel(b))  ·  Δ\(Int(distance.rounded())) cents"
                        ))
                        break
                    }
                }
            }
        }

        return events.sorted { $0.secondsAway < $1.secondsAway }.prefix(15).map { $0 }
    }

    private func toneLabel(_ tone: HarmonicTone) -> String {
        let tfName: String
        switch tone.timeframe {
        case .year: tfName = "YR"
        case .moon: tfName = "MN"
        case .quarterMoon: tfName = "QM"
        case .day: tfName = "DY"
        case .hour: tfName = "HR"
        case .minute: tfName = "MIN"
        }
        return tone.isFundamental ? tfName : "\(tfName)×\(tone.divisions)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds.isInfinite || seconds.isNaN { return "—" }
        let s = max(0, seconds)
        let year: Double = 365.25 * 24 * 3600
        let day: Double = 24 * 3600
        let hour: Double = 3600

        if s >= year { return String(format: "%.2f years", s / year) }
        if s >= day  { return String(format: "%.2f days",  s / day) }
        if s >= hour { return String(format: "%.2f hours", s / hour) }
        if s >= 60   { return String(format: "%.1f min",   s / 60) }
        return String(format: "%.0f sec", s)
    }
}
