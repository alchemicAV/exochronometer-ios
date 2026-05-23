import SwiftUI
import ExochronometerCore

enum ScaleMode: String {
    case lo
    case hi
    case merged

    /// Per-timeframe scale assignments. In merged mode each timeframe gets
    /// the smallest scale that puts its fundamental + overtones inside
    /// audible — hour can stay at 23, day/qtr need 26, moon/year need 29.
    var assignments: [ToneAssignment] {
        switch self {
        case .lo:
            return TimeFrame.allCases
                .filter { $0 != .minute }
                .map { ToneAssignment(timeframe: $0, scale: 23) }
        case .hi:
            return TimeFrame.allCases
                .filter { $0 != .minute }
                .map { ToneAssignment(timeframe: $0, scale: 26) }
        case .merged:
            return [
                ToneAssignment(timeframe: .hour,        scale: 23),
                ToneAssignment(timeframe: .day,         scale: 26),
                ToneAssignment(timeframe: .quarterMoon, scale: 28),
                ToneAssignment(timeframe: .moon,        scale: 29),
                ToneAssignment(timeframe: .year,        scale: 29),
            ]
        }
    }

    var label: String {
        switch self {
        case .lo:     return "2^23"
        case .hi:     return "2^26"
        case .merged: return "MERGED"
        }
    }

    var isActive: Bool { self != .lo }
    var isMerged: Bool { self == .merged }

    var next: ScaleMode {
        switch self {
        case .lo:     return .hi
        case .hi:     return .merged
        case .merged: return .lo
        }
    }

    var minFreqHz: Double {
        switch self {
        case .lo:     return 0.1
        case .hi:     return 1
        case .merged: return 1
        }
    }

    var maxFreqHz: Double {
        switch self {
        case .lo:     return 50_000
        case .hi:     return 200_000
        case .merged: return 50_000
        }
    }
}

struct HarmonicAnalysisPage: View {
    @StateObject private var audio = HarmonicAudio(assignments: ScaleMode.merged.assignments)
    @AppStorage("globalFundamentalsOff") private var fundamentalsOff: Bool = true
    @State private var scaleMode: ScaleMode = .merged
    @State private var volume: Double = 0.5

    var body: some View {
        VStack(spacing: 10) {
            header
            controlsRow
                .padding(.horizontal, 20)
            volumeRow
                .padding(.horizontal, 20)

            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                let active = activeTones(at: context.date)
                let displayedTones = fundamentalsOff
                    ? active.filter { $0.divisions != 1 }
                    : active

                VStack(spacing: 8) {
                    VerticalSpectrum(
                        tones: displayedTones,
                        minFreqHz: scaleMode.minFreqHz,
                        maxFreqHz: scaleMode.maxFreqHz,
                        showScaleSuffix: scaleMode.isMerged
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)

                    OscilloscopeView(tones: displayedTones)
                        .frame(height: 90)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                .onChange(of: context.date) { _, _ in
                    pushAudio(active: active)
                }
                .onAppear {
                    pushAudio(active: active)
                    audio.volume = volume
                }
            }
        }
        .padding(.top, 8)
        .onDisappear {
            audio.stop()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HARMONIC SPECTRUM")
                .font(.system(size: 10, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.6))
            Text(headerSubtitle)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var headerSubtitle: String {
        let scaleText: String
        switch scaleMode {
        case .lo:     scaleText = "× 2^23"
        case .hi:     scaleText = "× 2^26"
        case .merged: scaleText = "HR:23 · DY:26 · QM:28 · MN/YR:29"
        }
        return "\(scaleText)  ·  minute excluded"
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            toggleButton(
                label: audio.isRunning ? "AUDIO ON" : "AUDIO OFF",
                active: audio.isRunning
            ) {
                if audio.isRunning {
                    audio.stop()
                } else {
                    audio.start()
                }
            }

            toggleButton(
                label: scaleMode.label,
                active: scaleMode.isActive
            ) {
                scaleMode = scaleMode.next
                audio.reconfigure(assignments: scaleMode.assignments)
            }

            Spacer()
        }
    }

    private var volumeRow: some View {
        HStack(spacing: 10) {
            Text("VOL")
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
            MiniSlider(value: $volume, range: 0...1)
                .onChange(of: volume) { _, new in
                    audio.volume = new
                }
            Text("\(Int(volume * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func toggleButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(active ? .black : .white.opacity(0.7))
                .background(
                    Capsule().fill(active ? Color.white : .clear)
                )
                .overlay(
                    Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5)
                )
        }
    }

    private func activeTones(at date: Date) -> [SpectrumTone] {
        var out: [SpectrumTone] = []
        for entry in scaleMode.assignments {
            let tf = entry.timeframe
            let sc = entry.scale
            let factor = pow(2.0, Double(sc))
            let fundamental = (1.0 / tf.cycleDuration) * factor
            let degree = tf.degree(at: date)
            let nextDegree = degree + 1.0

            out.append(SpectrumTone(
                timeframe: tf,
                divisions: 1,
                octaves: sc,
                frequency: fundamental,
                amplitude: 1.0,
                state: .peak
            ))

            for div in 3...8 {
                let amp = FadeMath.shapeOpacity(currentDegree: degree, divisions: div)
                if amp > 0.01 {
                    let nextAmp = FadeMath.shapeOpacity(currentDegree: nextDegree, divisions: div)
                    let state: ToneState
                    if amp > 0.95 && abs(nextAmp - amp) < 0.02 {
                        state = .peak
                    } else if nextAmp > amp {
                        state = .waxing
                    } else if nextAmp < amp {
                        state = .waning
                    } else {
                        state = .peak
                    }
                    out.append(SpectrumTone(
                        timeframe: tf,
                        divisions: div,
                        octaves: sc,
                        frequency: fundamental * Double(div),
                        amplitude: amp,
                        state: state
                    ))
                }
            }
        }
        return out
    }

    private func pushAudio(active: [SpectrumTone]) {
        guard audio.isRunning else { return }
        var amps: [ToneID: Double] = [:]
        for tone in active {
            if fundamentalsOff && tone.divisions == 1 { continue }
            let id = ToneID(timeframe: tone.timeframe, divisions: tone.divisions, octaves: tone.octaves)
            amps[id] = tone.amplitude
        }
        audio.update(amplitudes: amps)
    }
}

enum ToneState {
    case waxing, peak, waning

    var label: String {
        switch self {
        case .waxing: return "WAXING"
        case .peak:   return "PEAK"
        case .waning: return "WANING"
        }
    }
}

struct SpectrumTone: Identifiable {
    let timeframe: TimeFrame
    let divisions: Int
    let octaves: Int
    let frequency: Double
    let amplitude: Double
    let state: ToneState

    var id: String { "\(timeframe.rawValue)-\(divisions)-\(octaves)" }
    var isFundamental: Bool { divisions == 1 }
}

private func compactTimeframeName(_ tf: TimeFrame) -> String {
    switch tf {
    case .year:        return "YEAR"
    case .moon:        return "MOON"
    case .quarterMoon: return "QTR"
    case .day:         return "DAY"
    case .hour:        return "HOUR"
    case .minute:      return "MIN"
    }
}

private func decadeValues(min: Double, max: Double) -> [Double] {
    let hi = log10(max)
    var values: [Double] = []
    var n = Int(floor(log10(min)))
    while pow(10.0, Double(n)) < min - 1e-12 { n += 1 }
    while Double(n) <= hi + 1e-12 {
        values.append(pow(10.0, Double(n)))
        n += 1
    }
    return values
}

private func decadeLabel(_ value: Double) -> String {
    if value >= 1_000_000 { return "\(Int(value / 1_000_000))M" }
    if value >= 1_000     { return "\(Int(value / 1_000))k" }
    if value >= 1         { return "\(Int(value))" }
    return String(format: "%g", value)
}

private struct MiniSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private let thumbSize: CGFloat = 12
    private let trackHeight: CGFloat = 2

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let halfThumb = thumbSize / 2
            let usable = max(0, width - thumbSize)
            let span = range.upperBound - range.lowerBound
            let normalized = span == 0 ? 0 : (value - range.lowerBound) / span
            let thumbCenter = halfThumb + CGFloat(normalized) * usable

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: thumbCenter, height: trackHeight)

                Circle()
                    .fill(.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbCenter - halfThumb)
            }
            .frame(width: width, height: thumbSize, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let x = max(halfThumb, min(width - halfThumb, drag.location.x))
                        let pct = usable > 0 ? (x - halfThumb) / usable : 0
                        value = range.lowerBound + Double(pct) * span
                    }
            )
        }
        .frame(height: thumbSize)
    }
}

private struct VerticalSpectrum: View {
    let tones: [SpectrumTone]
    let minFreqHz: Double
    let maxFreqHz: Double
    let showScaleSuffix: Bool

    var body: some View {
        Canvas { ctx, size in
            drawAll(in: &ctx, size: size)
        }
    }

    private func drawAll(in ctx: inout GraphicsContext, size: CGSize) {
        let logMin = log10(minFreqHz)
        let logMax = log10(maxFreqHz)
        let range = logMax - logMin
        guard range > 0 else { return }

        let axisWidth: CGFloat = 38
        let baselineX: CGFloat = axisWidth + 6
        let labelX: CGFloat = axisWidth + 6 + 140 + 8
        let maxBarWidth: CGFloat = 140
        let decades = decadeValues(min: minFreqHz, max: maxFreqHz)

        drawAudibleBand(in: &ctx, size: size, logMin: logMin, range: range, baselineX: baselineX)
        drawGrid(in: &ctx, size: size, logMin: logMin, range: range, baselineX: baselineX, decades: decades)
        drawAxisLabels(in: &ctx, size: size, logMin: logMin, range: range, decades: decades)
        drawTones(
            in: &ctx,
            size: size,
            logMin: logMin,
            range: range,
            baselineX: baselineX,
            maxBarWidth: maxBarWidth,
            labelX: labelX
        )
    }

    private func mapY(_ freq: Double, logMin: Double, range: Double, height: CGFloat) -> CGFloat {
        let frac = (log10(freq) - logMin) / range
        return height * (1.0 - CGFloat(frac))
    }

    private func drawAudibleBand(in ctx: inout GraphicsContext, size: CGSize, logMin: Double, range: Double, baselineX: CGFloat) {
        let yLo = mapY(20, logMin: logMin, range: range, height: size.height)
        let yHi = mapY(20_000, logMin: logMin, range: range, height: size.height)
        let band = CGRect(x: baselineX, y: yHi, width: size.width - baselineX, height: yLo - yHi)
        ctx.fill(Path(band), with: .color(.white.opacity(0.04)))
    }

    private func drawGrid(in ctx: inout GraphicsContext, size: CGSize, logMin: Double, range: Double, baselineX: CGFloat, decades: [Double]) {
        for d in decades {
            let y = mapY(d, logMin: logMin, range: range, height: size.height)
            var p = Path()
            p.move(to: CGPoint(x: baselineX, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
        }
        var spine = Path()
        spine.move(to: CGPoint(x: baselineX, y: 0))
        spine.addLine(to: CGPoint(x: baselineX, y: size.height))
        ctx.stroke(spine, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
    }

    private func drawAxisLabels(in ctx: inout GraphicsContext, size: CGSize, logMin: Double, range: Double, decades: [Double]) {
        for (i, d) in decades.enumerated() {
            let y = mapY(d, logMin: logMin, range: range, height: size.height)
            let label = i == 0 ? "\(decadeLabel(d)) Hz" : decadeLabel(d)
            let text = Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
            ctx.draw(text, at: CGPoint(x: 18, y: y), anchor: .center)
        }
    }

    private func drawTones(
        in ctx: inout GraphicsContext,
        size: CGSize,
        logMin: Double,
        range: Double,
        baselineX: CGFloat,
        maxBarWidth: CGFloat,
        labelX: CGFloat
    ) {
        for tone in tones {
            guard tone.frequency >= minFreqHz, tone.frequency <= maxFreqHz else { continue }
            let y = mapY(tone.frequency, logMin: logMin, range: range, height: size.height)
            let length = maxBarWidth * CGFloat(tone.amplitude)

            var bar = Path()
            bar.move(to: CGPoint(x: baselineX, y: y))
            bar.addLine(to: CGPoint(x: baselineX + length, y: y))

            let color: Color = tone.isFundamental ? .white : .white.opacity(0.85)
            let lineWidth: CGFloat = tone.isFundamental ? 1.5 : 0.8
            ctx.stroke(bar, with: .color(color), lineWidth: lineWidth)

            let dotR = 1.5 + tone.amplitude * 2.0
            let dot = CGRect(
                x: baselineX + length - dotR,
                y: y - dotR,
                width: dotR * 2,
                height: dotR * 2
            )
            ctx.fill(Path(ellipseIn: dot), with: .color(color))

            let name = compactTimeframeName(tone.timeframe)
            let prefix = tone.isFundamental ? name : "\(name)×\(tone.divisions)"
            let scaleSuffix = showScaleSuffix ? " @\(tone.octaves)" : ""
            let freqLabel = FrequencyMath.format(tone.frequency)
            let stateSuffix = tone.isFundamental ? "" : "  ·  \(tone.state.label)"
            let label = Text("\(prefix)\(scaleSuffix)  ·  \(freqLabel)\(stateSuffix)")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(tone.isFundamental ? 0.75 : 0.55))
            ctx.draw(label, at: CGPoint(x: labelX, y: y), anchor: .leading)
        }
    }
}

private struct OscilloscopeView: View {
    let tones: [SpectrumTone]
    private let windowSeconds: Double = 0.030

    var body: some View {
        Canvas { ctx, size in
            drawScope(in: &ctx, size: size)
        }
        .overlay(alignment: .topLeading) {
            Text("COMPOSITE WAVEFORM")
                .font(.system(size: 8, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.leading, 4)
                .padding(.top, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func drawScope(in ctx: inout GraphicsContext, size: CGSize) {
        var center = Path()
        center.move(to: CGPoint(x: 0, y: size.height / 2))
        center.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        ctx.stroke(center, with: .color(.white.opacity(0.1)), lineWidth: 0.5)

        guard !tones.isEmpty else { return }

        let samples = Int(size.width)
        var values: [Double] = Array(repeating: 0, count: samples)
        var peak: Double = 0

        for i in 0..<samples {
            let t = Double(i) / Double(samples) * windowSeconds
            var s: Double = 0
            for tone in tones {
                s += sin(2.0 * .pi * tone.frequency * t) * tone.amplitude
            }
            values[i] = s
            if abs(s) > peak { peak = abs(s) }
        }

        guard peak > 0 else { return }
        let scale = (size.height / 2 - 4) / peak

        var wave = Path()
        for i in 0..<samples {
            let x = CGFloat(i)
            let y = size.height / 2 - CGFloat(values[i] * scale)
            if i == 0 {
                wave.move(to: CGPoint(x: x, y: y))
            } else {
                wave.addLine(to: CGPoint(x: x, y: y))
            }
        }
        ctx.stroke(wave, with: .color(.white.opacity(0.85)), lineWidth: 1)
    }
}
