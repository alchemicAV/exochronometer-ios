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

    /// Frequency ratio in lowest integer terms. A winding tone's frequency
    /// is divisions/skip × fundamental, so the pair ratio is
    /// (aDiv·bSkip):(bDiv·aSkip).
    private var ratio: (m: Int, n: Int) {
        let a = pair.a.divisions * pair.b.skip
        let b = pair.b.divisions * pair.a.skip
        let g = gcd(a, b)
        return (a / g, b / g)
    }

    private var label: String {
        let r = ratio
        return "\(r.m):\(r.n)"
    }

    private func drawCurve(in ctx: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(size.width, size.height) / 2 - 4

        let (m, n) = ratio

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

private struct ConvergenceView: View {
    @AppStorage("globalFundamentalsOff") private var fundamentalsOff: Bool = true

    private static let lookahead: TimeInterval = 30 * 86400 // 1 month
    private static let maxResults = 40

    @State private var current: [ChordMatch] = []
    @State private var events: [ChordEvent] = []
    @State private var loading: Bool = true
    @State private var anchorDate: Date = .distantPast

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1.0)) { context in
            content(at: context.date)
        }
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                currentSection(now: date)
                upcomingSection(now: date)
            }
            .padding(.vertical, 8)
        }
        .task(id: recomputeKey(for: date)) {
            await recompute(at: date)
        }
    }

    private func recomputeKey(for date: Date) -> String {
        let bucket = Int(date.timeIntervalSinceReferenceDate / 300)
        return "\(bucket)|\(fundamentalsOff ? 1 : 0)|H"
    }

    @ViewBuilder
    private func currentSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOW")
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
            if loading {
                Text("…computing")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            } else if current.isEmpty {
                Text("no recognized chord active")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(current.prefix(5), id: \.id) { match in
                    currentRow(match)
                }
            }
        }
    }

    @ViewBuilder
    private func upcomingSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CROSS-TIMEFRAME CONVERGENCES")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                Text("next 30 days  ·  nearest first")
                    .font(.system(size: 8, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.top, 4)
            if loading {
                Text("…computing")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            } else if events.isEmpty {
                Text("none predicted in window")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(events, id: \.id) { event in
                    upcomingRow(event, now: now)
                }
            }
        }
    }

    private func currentRow(_ match: ChordMatch) -> some View {
        HStack {
            Text(match.pattern.abbreviation)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
            Text(signatureText(match.tones.map {
                ChordEvent.ToneSignature(timeframe: $0.timeframe, divisions: $0.divisions, skip: $0.skip)
            }))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text("fit \(String(format: "%.1f", match.fitCents))¢")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func upcomingRow(_ event: ChordEvent, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(event.pattern.abbreviation)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                Text(signatureText(event.toneSignature))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(timeUntil(event.startTime, from: now))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
            HStack(spacing: 10) {
                Text("fit \(String(format: "%.1f", event.fitCents))¢")
                Text("dur \(durationText(event.endTime.timeIntervalSince(event.startTime)))")
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func signatureText(_ sig: [ChordEvent.ToneSignature]) -> String {
        sig.map { compactTF($0.timeframe) + ":" + $0.divisionLabel }
            .joined(separator: " · ")
    }

    private func compactTF(_ tf: TimeFrame) -> String {
        switch tf {
        case .year:        return "YR"
        case .moon:        return "MN"
        case .quarterMoon: return "QM"
        case .day:         return "DY"
        case .hour:        return "HR"
        case .minute:      return "MIN"
        }
    }

    private func timeUntil(_ d: Date, from now: Date) -> String {
        let s = d.timeIntervalSince(now)
        return durationText(max(0, s))
    }

    private func durationText(_ s: TimeInterval) -> String {
        if s < 60 { return String(format: "%.0fs", s) }
        if s < 3600 {
            return String(format: "%.0fm", floor(s / 60))
        }
        if s < 86400 {
            let h = floor(s / 3600)
            let m = floor(s.truncatingRemainder(dividingBy: 3600) / 60)
            return String(format: "%.0fh%.0fm", h, m)
        }
        let d = floor(s / 86400)
        let h = floor(s.truncatingRemainder(dividingBy: 86400) / 3600)
        return String(format: "%.0fd%.0fh", d, h)
    }

    private func recompute(at date: Date) async {
        await MainActor.run { loading = true }
        let includeFundamentals = !fundamentalsOff
        // iOS doesn't have per-widget settings, so the hour-exclusion
        // default is hardcoded here to match the Mac default.
        let excludeHourly = true
        let upcoming = await Task.detached(priority: .userInitiated) {
            ChordProjector.upcoming(
                from: date,
                lookahead: Self.lookahead,
                includeFundamentals: includeFundamentals,
                crossTimeframeOnly: true,
                excludeHourly: excludeHourly,
                patterns: ChordCatalog.chords,
                maxResults: Self.maxResults
            )
        }.value
        let nowMatches = await Task.detached(priority: .userInitiated) {
            ChordProjector.current(
                at: date,
                includeFundamentals: includeFundamentals,
                excludeHourly: excludeHourly,
                patterns: ChordCatalog.chords
            )
        }.value
        await MainActor.run {
            self.events = upcoming
            self.current = nowMatches
            self.anchorDate = date
            self.loading = false
        }
    }
}
