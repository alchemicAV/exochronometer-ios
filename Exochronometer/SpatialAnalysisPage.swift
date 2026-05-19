import SwiftUI
import ExochronometerCore

enum SpatialMode: String, CaseIterable, Identifiable {
    case lissajous
    case spectrogram
    case chladni
    case convergence

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lissajous:    return "LISSAJOUS"
        case .spectrogram:  return "SPECTROGRAM"
        case .chladni:      return "CHLADNI"
        case .convergence:  return "CONVERGENCE"
        }
    }

    var subtitle: String {
        switch self {
        case .lissajous:   return "within-timeframe pairs · ratios from active harmonics"
        case .spectrogram: return "60-second rolling spectrum (pre-populated on entry)"
        case .chladni:     return "2D membrane modes summed by amplitude"
        case .convergence: return "time until next angular alignment (live)"
        }
    }
}

struct SpatialAnalysisPage: View {
    @State private var mode: SpatialMode = .lissajous

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

// MARK: - Lissajous (within-timeframe pairs of active tones)

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

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: false)) { context in
            let pairs = withinTimeframePairs(at: context.date)

            if pairs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(pairs) { pair in
                            LissajousCell(pair: pair)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func withinTimeframePairs(at date: Date) -> [LissajousPair] {
        let tones = HarmonicAnalysis.activeTones(at: date, scales: [scaling])
        let grouped = Dictionary(grouping: tones, by: { $0.timeframe })
        var pairs: [LissajousPair] = []
        for tf in TimeFrame.allCases where tf != .minute {
            let group = grouped[tf] ?? []
            guard group.count >= 2 else { continue }
            for i in 0..<group.count {
                for j in (i + 1)..<group.count {
                    pairs.append(LissajousPair(a: group[i], b: group[j]))
                }
            }
        }
        return pairs
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("NO ACTIVE PAIRS")
                .font(.system(size: 11, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.5))
            Text("waiting for overtones to light up")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .font(.system(size: 8, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var label: String {
        let tfName = nameOf(pair.a.timeframe)
        let aDiv = pair.a.divisions
        let bDiv = pair.b.divisions
        let g = gcd(aDiv, bDiv)
        let aReduced = aDiv / g
        let bReduced = bDiv / g
        return "\(tfName)   \(aReduced):\(bReduced)"
    }

    private func nameOf(_ tf: TimeFrame) -> String {
        switch tf {
        case .year:        return "YEAR"
        case .moon:        return "MOON"
        case .quarterMoon: return "QTR"
        case .day:         return "DAY"
        case .hour:        return "HOUR"
        case .minute:      return "MIN"
        }
    }

    private func drawCurve(in ctx: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(size.width, size.height) / 2 - 4

        // Reduce to lowest-terms integer ratio so the Lissajous renders as
        // the canonical closed curve for that ratio.
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
        let amp = (pair.a.amplitude * pair.b.amplitude)
        let opacity = pair.a.isFundamental && pair.b.isFundamental ? 0.85 : (0.4 + 0.5 * amp)
        ctx.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 0.7)
    }
}

// MARK: - Spectrogram (deterministic pre-populated history)

private final class SpectrogramBuffer: ObservableObject {
    @Published private(set) var frames: [Frame] = []
    private var lastSample: Date = .distantPast

    struct Frame: Identifiable {
        let id: Date
        let tones: [HarmonicTone]
    }

    let sampleInterval: TimeInterval = 0.5
    let maxAge: TimeInterval = 60

    func sampleIfDue(at date: Date, tones: [HarmonicTone]) {
        if date.timeIntervalSince(lastSample) < sampleInterval { return }
        lastSample = date
        frames.append(Frame(id: date, tones: tones))
        let cutoff = date.addingTimeInterval(-maxAge)
        frames.removeAll { $0.id < cutoff }
    }

    /// Build the full history retroactively from the deterministic harmonic
    /// math so the spectrogram is populated the instant the user enters.
    func prePopulate(now: Date, scales: [Int]) {
        var built: [Frame] = []
        var t = now.addingTimeInterval(-maxAge)
        while t <= now {
            let tones = HarmonicAnalysis.activeTones(at: t, scales: scales)
            built.append(Frame(id: t, tones: tones))
            t = t.addingTimeInterval(sampleInterval)
        }
        frames = built
        lastSample = now
    }
}

private struct SpectrogramView: View {
    @StateObject private var buffer = SpectrogramBuffer()

    private let scaling: Int = 23
    private let minFreqHz: Double = 0.1
    private let maxFreqHz: Double = 50_000
    private let windowSeconds: TimeInterval = 60

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let tones = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])

            Canvas { ctx, size in
                drawScope(in: &ctx, size: size, now: context.date)
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
            .onChange(of: context.date) { _, newDate in
                buffer.sampleIfDue(at: newDate, tones: tones)
            }
            .onAppear {
                if buffer.frames.isEmpty {
                    buffer.prePopulate(now: Date(), scales: [scaling])
                }
            }
        }
    }

    private func drawScope(in ctx: inout GraphicsContext, size: CGSize, now: Date) {
        let logMin = log10(minFreqHz)
        let logMax = log10(maxFreqHz)
        let range = logMax - logMin
        guard range > 0 else { return }

        let axisWidth: CGFloat = 30
        let plotX = axisWidth
        let plotWidth = size.width - axisWidth

        for d in [0.1, 1.0, 10.0, 100.0, 1_000.0, 10_000.0] {
            let y = mapY(d, logMin: logMin, range: range, height: size.height)
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
            if age > windowSeconds { continue }
            let xFrac = 1.0 - (age / windowSeconds)
            let x = plotX + CGFloat(xFrac) * plotWidth

            for tone in frame.tones {
                guard tone.frequency >= minFreqHz, tone.frequency <= maxFreqHz else { continue }
                let y = mapY(tone.frequency, logMin: logMin, range: range, height: size.height)
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

        for s in [-60.0, -45.0, -30.0, -15.0, 0.0] {
            let xFrac = 1.0 + s / windowSeconds
            if xFrac < 0 || xFrac > 1 { continue }
            let x = plotX + CGFloat(xFrac) * plotWidth
            let label = s == 0 ? "now" : "\(Int(s))s"
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
    private let scaling: Int = 23

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { context in
            let tones = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])

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
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func eventRow(_ event: ConvergenceEvent) -> some View {
        HStack {
            Text(event.label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(formatDuration(event.secondsAway))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
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

    /// Time until the two dots are next at the same degree on their cycles.
    /// Computed from the current angular difference and the difference in
    /// angular velocities (a linear-rate approximation, fine for any window).
    private func secondsUntilAligned(a: TimeFrame, b: TimeFrame, now: Date) -> TimeInterval? {
        let rateA = 360.0 / a.cycleDuration  // deg/sec
        let rateB = 360.0 / b.cycleDuration
        let relRate = rateA - rateB
        guard abs(relRate) > 1e-12 else { return nil }

        let degA = a.degree(at: now)
        let degB = b.degree(at: now)
        var diff = (degA - degB).truncatingRemainder(dividingBy: 360)
        if diff < 0 { diff += 360 }
        if diff < 1e-6 { return 360 / abs(relRate) }  // aligned now; show next alignment

        // D(t) = degA(t) - degB(t) changes at relRate. Find when D ≡ 0 (mod 360).
        let distance: Double = relRate > 0 ? (360 - diff) : diff
        return distance / abs(relRate)
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
