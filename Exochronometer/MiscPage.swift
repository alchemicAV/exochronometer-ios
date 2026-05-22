import SwiftUI
import ExochronometerCore

enum MiscMode: String, CaseIterable, Identifiable {
    case phasePortrait
    case centsWheel
    case dissonance
    case colorMapping

    var id: String { rawValue }

    var label: String {
        switch self {
        case .phasePortrait: return "PHASE"
        case .centsWheel:    return "CENTS"
        case .dissonance:    return "DISSONANCE"
        case .colorMapping:  return "COLOR"
        }
    }

    var subtitle: String {
        switch self {
        case .phasePortrait: return "signal vs derivative · closed orbits = periodic"
        case .centsWheel:    return "pitch class wheel relative to A4 = 432 Hz"
        case .dissonance:    return "Tenney height + Shannon entropy of JI guesses"
        case .colorMapping:  return "pitch class mapped to visible wavelength"
        }
    }
}

struct MiscPage: View {
    @State private var mode: MiscMode = .phasePortrait

    var body: some View {
        VStack(spacing: 10) {
            header

            modePicker
                .padding(.horizontal, 16)

            Group {
                switch mode {
                case .phasePortrait: PhasePortraitView()
                case .centsWheel:    CentsWheelView()
                case .dissonance:    DissonanceView()
                case .colorMapping:  ColorMappingView()
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
            Text("MISC ANALYSIS")
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
                ForEach(MiscMode.allCases) { m in
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

// MARK: - Phase Portrait

private struct PhasePortraitView: View {
    @AppStorage("globalFundamentalsOff") private var fundamentalsOff: Bool = true
    private let scaling: Int = 23
    private let windowSeconds: Double = 0.030

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let all = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let tones = fundamentalsOff ? all.filter { !$0.isFundamental } : all

            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    drawPortrait(in: &ctx, size: size, tones: tones)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("plot of  ( s(t),  ds/dt )")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("clean closed loop  →  periodic chord (small-integer ratios)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("dense filled region  →  quasi-periodic (incommensurate ratios)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(fundamentalsOff ? "fundamentals filtered out (global)" : "fundamentals included")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    private func drawPortrait(in ctx: inout GraphicsContext, size: CGSize, tones: [HarmonicTone]) {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(size.width, size.height) / 2 - 8

        var axes = Path()
        axes.move(to: CGPoint(x: cx - r, y: cy))
        axes.addLine(to: CGPoint(x: cx + r, y: cy))
        axes.move(to: CGPoint(x: cx, y: cy - r))
        axes.addLine(to: CGPoint(x: cx, y: cy + r))
        ctx.stroke(axes, with: .color(.white.opacity(0.12)), lineWidth: 0.5)

        guard !tones.isEmpty else { return }

        let samples = 800
        var sigs: [Double] = []
        var deriv: [Double] = []
        var peakSig: Double = 0
        var peakDeriv: Double = 0

        for i in 0..<samples {
            let t = Double(i) / Double(samples) * windowSeconds
            var s: Double = 0
            var d: Double = 0
            for tone in tones {
                let w = 2 * .pi * tone.frequency
                s += sin(w * t) * tone.amplitude
                d += cos(w * t) * tone.amplitude * w
            }
            sigs.append(s)
            deriv.append(d)
            if abs(s) > peakSig   { peakSig = abs(s) }
            if abs(d) > peakDeriv { peakDeriv = abs(d) }
        }

        guard peakSig > 0, peakDeriv > 0 else { return }
        let sScale = r / CGFloat(peakSig)
        let dScale = r / CGFloat(peakDeriv)

        var path = Path()
        for i in 0..<samples {
            let x = cx + CGFloat(sigs[i]) * sScale
            let y = cy - CGFloat(deriv[i]) * dScale
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else      { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(path, with: .color(.white.opacity(0.85)), lineWidth: 1)
    }
}

// MARK: - Cents Wheel

private struct CentsWheelView: View {
    @AppStorage("globalFundamentalsOff") private var fundamentalsOff: Bool = true
    private let scaling: Int = 23
    private let reference: Double = 432.0  // A4 = 432 Hz

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: false)) { context in
            let tones = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let displayed = fundamentalsOff ? tones.filter { !$0.isFundamental } : tones

            Canvas { ctx, size in
                drawWheel(in: &ctx, size: size, tones: displayed)
            }
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    private func drawWheel(in ctx: inout GraphicsContext, size: CGSize, tones: [HarmonicTone]) {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(size.width, size.height) / 2 - 30

        var outline = Path()
        outline.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.stroke(outline, with: .color(.white.opacity(0.3)), lineWidth: 0.6)

        let noteNames = ["A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#"]
        for (i, name) in noteNames.enumerated() {
            let angle = (Double(i) / 12.0) * 2 * .pi - .pi / 2
            let lx = cx + (r + 14) * CGFloat(cos(angle))
            let ly = cy + (r + 14) * CGFloat(sin(angle))
            let text = Text(name)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            ctx.draw(text, at: CGPoint(x: lx, y: ly), anchor: .center)

            var tick = Path()
            let tickInner = r - 4
            let tickOuter = r + 1
            tick.move(to: CGPoint(x: cx + tickInner * CGFloat(cos(angle)), y: cy + tickInner * CGFloat(sin(angle))))
            tick.addLine(to: CGPoint(x: cx + tickOuter * CGFloat(cos(angle)), y: cy + tickOuter * CGFloat(sin(angle))))
            ctx.stroke(tick, with: .color(.white.opacity(0.2)), lineWidth: 0.5)
        }

        for tone in tones {
            guard tone.frequency > 0 else { continue }
            let cents = 1200 * log2(tone.frequency / reference)
            let pitchClass = (cents.truncatingRemainder(dividingBy: 1200) + 1200).truncatingRemainder(dividingBy: 1200)
            let angle = (pitchClass / 1200) * 2 * .pi - .pi / 2
            let dotR: CGFloat = tone.isFundamental ? 5 : 3 + CGFloat(tone.amplitude * 2)
            let x = cx + r * CGFloat(cos(angle))
            let y = cy + r * CGFloat(sin(angle))
            let alpha = tone.isFundamental ? 0.95 : tone.amplitude * 0.9
            let dot = CGRect(x: x - dotR, y: y - dotR, width: dotR * 2, height: dotR * 2)
            ctx.fill(Path(ellipseIn: dot), with: .color(.white.opacity(alpha)))
        }
    }
}

// MARK: - Dissonance (Tenney height + Harmonic Entropy)

private struct DissonanceView: View {
    @AppStorage("globalFundamentalsOff") private var fundamentalsOff: Bool = true
    private let scaling: Int = 23

    /// Just-intonation reference set. Each ratio's Tenney height = log2(n*d).
    /// 1:1 (Tenney 0) is most consonant; 45:32 (Tenney ~10.5) is most dissonant
    /// of the standard set.
    private static let jiRatios: [(n: Int, d: Int)] = [
        (1, 1),
        (16, 15),
        (9, 8),
        (6, 5),
        (5, 4),
        (4, 3),
        (45, 32),
        (3, 2),
        (8, 5),
        (5, 3),
        (7, 4),
        (15, 8),
        (2, 1),
    ]

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 5.0, paused: false)) { context in
            let all = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let tones = fundamentalsOff ? all.filter { !$0.isFundamental } : all
            let pairCount = max(1, tones.count * (tones.count - 1) / 2)

            let tenney = totalTenney(tones)
            let entropy = totalEntropy(tones)

            // Normalize each by per-pair maximum to make the meter meaningful.
            let maxTenney = log2(45.0 * 32.0)   // worst Tenney in our ratio set
            let maxEntropy = log(Double(Self.jiRatios.count))
            let normTenney = min(1.0, tenney / (maxTenney * Double(pairCount)))
            let normEntropy = min(1.0, entropy / (maxEntropy * Double(pairCount)))

            ScrollView {
                VStack(spacing: 28) {
                    measureBlock(
                        title: "TENNEY  DISSONANCE",
                        rawValue: tenney,
                        normalized: normTenney,
                        leftLabel: "CONSONANT",
                        rightLabel: "DISSONANT",
                        caption: "ratio complexity · log2(n·d), weighted by amplitude"
                    )

                    measureBlock(
                        title: "HARMONIC  ENTROPY",
                        rawValue: entropy,
                        normalized: normEntropy,
                        leftLabel: "CLEAR",
                        rightLabel: "AMBIGUOUS",
                        caption: "Shannon entropy of JI ratio identity"
                    )

                    Text("\(tones.count) active tones · \(pairCount) pairs")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    private func measureBlock(
        title: String,
        rawValue: Double,
        normalized: Double,
        leftLabel: String,
        rightLabel: String,
        caption: String
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.55))

            Text(String(format: "%.3f", rawValue))
                .font(.system(size: 30, weight: .ultraLight, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))

            meter(value: normalized)
                .frame(height: 8)

            HStack {
                Text(leftLabel)
                    .font(.system(size: 8, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(rightLabel)
                    .font(.system(size: 8, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Text(caption)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
    }

    private func meter(value: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, value))))
            }
        }
    }

    /// Tenney-height dissonance: for each pair, take a Gaussian-weighted
    /// average of log2(n*d) over the JI ratio set (heavier weight where
    /// the pair's cents distance is small). Sum across pairs weighted by
    /// amplitude product.
    private func totalTenney(_ tones: [HarmonicTone]) -> Double {
        guard tones.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<tones.count {
            for j in (i + 1)..<tones.count {
                let a = tones[i]
                let b = tones[j]
                guard a.frequency > 0, b.frequency > 0 else { continue }
                let lo = min(a.frequency, b.frequency)
                let hi = max(a.frequency, b.frequency)
                let cents = abs(1200 * log2(hi / lo))
                let h = pairTenney(cents: cents)
                total += h * a.amplitude * b.amplitude
            }
        }
        return total
    }

    private func pairTenney(cents: Double, sigma: Double = 30) -> Double {
        let octaveCents = (cents.truncatingRemainder(dividingBy: 1200) + 1200)
            .truncatingRemainder(dividingBy: 1200)
        var weighted: Double = 0
        var weightSum: Double = 0
        for (n, d) in Self.jiRatios {
            let ratioCents = 1200 * log2(Double(n) / Double(d))
            let dist = min(
                abs(octaveCents - ratioCents),
                abs(octaveCents - ratioCents - 1200),
                abs(octaveCents - ratioCents + 1200)
            )
            let w = exp(-dist * dist / (2 * sigma * sigma))
            let tenney = log2(Double(n * d))
            weighted += tenney * w
            weightSum += w
        }
        guard weightSum > 0 else { return log2(45.0 * 32.0) }
        return weighted / weightSum
    }

    /// Same harmonic entropy as before: Shannon entropy of the Gaussian
    /// probability distribution over JI ratios at the pair's cents.
    private func totalEntropy(_ tones: [HarmonicTone]) -> Double {
        guard tones.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<tones.count {
            for j in (i + 1)..<tones.count {
                let a = tones[i]
                let b = tones[j]
                guard a.frequency > 0, b.frequency > 0 else { continue }
                let cents = abs(1200 * log2(b.frequency / a.frequency))
                let h = pairEntropy(cents: cents)
                total += h * a.amplitude * b.amplitude
            }
        }
        return total
    }

    private func pairEntropy(cents: Double, sigma: Double = 30) -> Double {
        let octaveCents = (cents.truncatingRemainder(dividingBy: 1200) + 1200)
            .truncatingRemainder(dividingBy: 1200)
        var probs: [Double] = []
        probs.reserveCapacity(Self.jiRatios.count)
        for (n, d) in Self.jiRatios {
            let ratioCents = 1200 * log2(Double(n) / Double(d))
            let dist = min(
                abs(octaveCents - ratioCents),
                abs(octaveCents - ratioCents - 1200),
                abs(octaveCents - ratioCents + 1200)
            )
            probs.append(exp(-dist * dist / (2 * sigma * sigma)))
        }
        let sum = probs.reduce(0, +)
        guard sum > 0 else { return log(Double(probs.count)) }
        var h: Double = 0
        for p in probs where p > 1e-10 {
            let pn = p / sum
            h -= pn * log(pn)
        }
        return h
    }
}

// MARK: - Color Mapping (pitch-class to visible wavelength)

private struct ColorMappingView: View {
    @AppStorage("globalFundamentalsOff") private var fundamentalsOff: Bool = true
    private let scaling: Int = 23
    private let orderedTimeframes: [TimeFrame] = [.hour, .day, .quarterMoon, .moon, .year]

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: false)) { context in
            let all = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let tones = fundamentalsOff ? all.filter { !$0.isFundamental } : all

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    swatch(
                        title: "COMPOSITE",
                        color: blendedColor(tones),
                        count: tones.count,
                        height: 90
                    )

                    Text("PER TIMEFRAME")
                        .font(.system(size: 8, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 8)

                    ForEach(orderedTimeframes, id: \.self) { tf in
                        let group = tones.filter { $0.timeframe == tf }
                        swatch(
                            title: timeframeLabel(tf),
                            color: blendedColor(group),
                            count: group.count,
                            height: 36
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func swatch(title: String, color: Color, count: Int, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
        }
    }

    private func timeframeLabel(_ tf: TimeFrame) -> String {
        switch tf {
        case .year:        return "YEAR"
        case .moon:        return "MOON CYCLE"
        case .quarterMoon: return "1/4 MOON"
        case .day:         return "ONE DAY"
        case .hour:        return "ONE HOUR"
        case .minute:      return "ONE MINUTE"
        }
    }

    private func blendedColor(_ tones: [HarmonicTone]) -> Color {
        guard !tones.isEmpty else { return .black }
        var r: Double = 0, g: Double = 0, b: Double = 0, w: Double = 0
        for tone in tones {
            guard tone.frequency > 0 else { continue }
            let logF = log2(tone.frequency)
            var pitchClass = logF - floor(logF)
            if pitchClass < 0 { pitchClass += 1 }
            let wavelength = 700.0 - pitchClass * (700.0 - 380.0)
            let (cr, cg, cb) = wavelengthToRGB(wavelength)
            r += cr * tone.amplitude
            g += cg * tone.amplitude
            b += cb * tone.amplitude
            w += tone.amplitude
        }
        guard w > 0 else { return .black }
        return Color(red: r / w, green: g / w, blue: b / w)
    }

    /// Bruton's wavelength-to-RGB approximation, nm -> sRGB triplet.
    private func wavelengthToRGB(_ wavelength: Double) -> (Double, Double, Double) {
        var r: Double = 0, g: Double = 0, b: Double = 0
        switch wavelength {
        case 380..<440:
            r = -(wavelength - 440) / (440 - 380)
            b = 1
        case 440..<490:
            g = (wavelength - 440) / (490 - 440)
            b = 1
        case 490..<510:
            g = 1
            b = -(wavelength - 510) / (510 - 490)
        case 510..<580:
            r = (wavelength - 510) / (580 - 510)
            g = 1
        case 580..<645:
            r = 1
            g = -(wavelength - 645) / (645 - 580)
        case 645...780:
            r = 1
        default:
            break
        }
        return (r, g, b)
    }
}
