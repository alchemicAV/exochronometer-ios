import SwiftUI
import SceneKit
import ExochronometerCore

enum MiscMode: String, CaseIterable, Identifiable {
    case phasePortrait
    case centsWheel
    case consonance
    case colorMapping
    case mandala
    case harmonicEntropy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .phasePortrait:   return "PHASE"
        case .centsWheel:      return "CENTS"
        case .consonance:      return "ROUGHNESS"
        case .colorMapping:    return "COLOR"
        case .mandala:         return "MANDALA"
        case .harmonicEntropy: return "ENTROPY"
        }
    }

    var subtitle: String {
        switch self {
        case .phasePortrait:   return "signal vs derivative · closed orbits = periodic"
        case .centsWheel:      return "pitch class wheel relative to A4 = 432 Hz"
        case .consonance:      return "Plomp-Levelt roughness across active pairs"
        case .colorMapping:    return "log frequency mapped to hue · amplitude to weight"
        case .mandala:         return "3D mandala · default polygons stacked in space"
        case .harmonicEntropy: return "Shannon entropy of just-intonation ratio guesses"
        }
    }
}

private func miscToggleButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(.system(size: 9, design: .monospaced))
            .tracking(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(active ? .black : .white.opacity(0.7))
            .background(Capsule().fill(active ? Color.white : .clear))
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5))
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
                case .phasePortrait:   PhasePortraitView()
                case .centsWheel:      CentsWheelView()
                case .consonance:      ConsonanceView()
                case .colorMapping:    ColorMappingView()
                case .mandala:         MandalaView()
                case .harmonicEntropy: HarmonicEntropyView()
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
    private let scaling: Int = 23
    private let windowSeconds: Double = 0.030

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let tones = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])

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
                    Text("the timeframes are mutually incommensurate by nature")
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
    @State private var fundamentalsOff: Bool = true
    private let scaling: Int = 23
    private let reference: Double = 432.0  // A4 = 432 Hz

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: false)) { context in
            let tones = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let displayed = fundamentalsOff ? tones.filter { !$0.isFundamental } : tones

            VStack(spacing: 8) {
                HStack {
                    miscToggleButton(
                        label: fundamentalsOff ? "FUND OFF" : "FUND ON",
                        active: !fundamentalsOff
                    ) {
                        fundamentalsOff.toggle()
                    }
                    Spacer()
                }

                Canvas { ctx, size in
                    drawWheel(in: &ctx, size: size, tones: displayed)
                }
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
            }
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

// MARK: - Consonance / Roughness

private struct ConsonanceView: View {
    private let scaling: Int = 23

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: false)) { context in
            let tones = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let roughness = totalRoughness(tones)
            let normalized = min(1.0, roughness / 4.0)

            VStack(spacing: 20) {
                Text(String(format: "%.3f", roughness))
                    .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                meter(value: normalized)
                    .frame(height: 12)

                HStack {
                    Text("CONSONANT")
                        .font(.system(size: 8, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text("DISSONANT")
                        .font(.system(size: 8, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Text("\(tones.count) active tones · \(tones.count * (tones.count - 1) / 2) pairs")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 24)
        }
    }

    private func meter(value: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: proxy.size.width * CGFloat(value))
            }
        }
    }

    /// Plomp & Levelt model — sum of pairwise roughness contributions,
    /// weighted by tone amplitudes.
    private func totalRoughness(_ tones: [HarmonicTone]) -> Double {
        guard tones.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 0..<tones.count {
            for j in (i + 1)..<tones.count {
                total += pairRoughness(tones[i], tones[j])
            }
        }
        return total
    }

    private func pairRoughness(_ a: HarmonicTone, _ b: HarmonicTone) -> Double {
        let f1 = min(a.frequency, b.frequency)
        let f2 = max(a.frequency, b.frequency)
        guard f1 > 0 else { return 0 }
        let cb = 1.72 * pow(f1, 0.65)
        let x = (f2 - f1) / (0.65 * cb)
        let r = exp(-3.5 * x) - exp(-5.75 * x)
        return max(0, r) * a.amplitude * b.amplitude
    }
}

// MARK: - Color Mapping

private struct ColorMappingView: View {
    private let scaling: Int = 23

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let tones = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let color = blendedColor(tones)

            ZStack {
                color
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                VStack {
                    Spacer()
                    Text(stats(tones))
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .black, radius: 3)
                        .padding(.bottom, 16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    private func blendedColor(_ tones: [HarmonicTone]) -> Color {
        guard !tones.isEmpty else { return .black }
        var rSum: Double = 0
        var gSum: Double = 0
        var bSum: Double = 0
        var weightSum: Double = 0

        for tone in tones {
            let hue = hueFor(frequency: tone.frequency)
            let (r, g, b) = rgbFromHue(hue)
            let w = tone.amplitude
            rSum += r * w
            gSum += g * w
            bSum += b * w
            weightSum += w
        }
        guard weightSum > 0 else { return .black }
        return Color(
            red: rSum / weightSum,
            green: gSum / weightSum,
            blue: bSum / weightSum
        )
    }

    /// Map log frequency to hue. 0.1 Hz -> red, 50 kHz -> violet, log scale.
    private func hueFor(frequency: Double) -> Double {
        let logF = log10(max(0.0001, frequency))
        let lo = log10(0.1)
        let hi = log10(50_000.0)
        let frac = (logF - lo) / (hi - lo)
        return min(1, max(0, frac)) * 0.85  // 0..0.85 covers red->violet without wrapping
    }

    private func rgbFromHue(_ hue: Double) -> (Double, Double, Double) {
        let h = hue * 6
        let i = Int(h)
        let f = h - Double(i)
        switch i % 6 {
        case 0: return (1, f, 0)
        case 1: return (1 - f, 1, 0)
        case 2: return (0, 1, f)
        case 3: return (0, 1 - f, 1)
        case 4: return (f, 0, 1)
        default: return (1, 0, 1 - f)
        }
    }

    private func stats(_ tones: [HarmonicTone]) -> String {
        "\(tones.count) tones blended"
    }
}

// MARK: - 3D Mandala

private struct MandalaView: View {
    @State private var scene: SCNScene = MandalaView.buildScene()

    var body: some View {
        SceneView(
            scene: scene,
            options: [.allowsCameraControl]
        )
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private static func buildScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(0, 0, 14)
        scene.rootNode.addChildNode(cameraNode)

        let mandala = SCNNode()
        let shapes = GeometryMath.defaultShapes
        let center = Double(shapes.count - 1) / 2
        for (idx, shape) in shapes.enumerated() {
            let z = Float((Double(idx) - center) * 0.5)
            mandala.addChildNode(makePolygon(shape: shape, z: z))
        }

        let rotation = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0.4, y: 1.0, z: 0.1, duration: 30)
        )
        mandala.runAction(rotation)
        scene.rootNode.addChildNode(mandala)

        return scene
    }

    private static func makePolygon(shape: GeometryMath.Shape, z: Float) -> SCNNode {
        let radius: Float = 2.5
        var vertices: [SCNVector3] = []
        vertices.reserveCapacity(shape.divisions)
        for i in 0..<shape.divisions {
            let angle = Float(i) * .pi * 2 / Float(shape.divisions) - .pi / 2
            vertices.append(SCNVector3(
                radius * cos(angle),
                radius * sin(angle),
                z
            ))
        }

        var indices: [UInt16] = []
        indices.reserveCapacity(shape.path.count * 2)
        for edge in shape.path {
            indices.append(UInt16(edge.from))
            indices.append(UInt16(edge.to))
        }

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .line
        )
        let geometry = SCNGeometry(sources: [source], elements: [element])

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.7)
        material.lightingModel = .constant
        material.isDoubleSided = true
        geometry.materials = [material]

        return SCNNode(geometry: geometry)
    }
}

// MARK: - Harmonic Entropy

private struct HarmonicEntropyView: View {
    private let scaling: Int = 23

    private static let jiRatios: [Double] = [
        1.0,
        16.0/15,
        9.0/8,
        6.0/5,
        5.0/4,
        4.0/3,
        45.0/32,
        3.0/2,
        8.0/5,
        5.0/3,
        7.0/4,
        15.0/8,
        2.0,
    ]

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 5.0, paused: false)) { context in
            let tones = HarmonicAnalysis.activeTones(at: context.date, scales: [scaling])
            let entropy = totalEntropy(tones)
            let maxEntropy = log(Double(Self.jiRatios.count))
            let normalized = maxEntropy > 0 ? min(1.0, entropy / (maxEntropy * Double(max(1, tones.count * (tones.count - 1) / 2)))) : 0

            VStack(spacing: 20) {
                Text(String(format: "%.3f", entropy))
                    .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))

                meter(value: normalized)
                    .frame(height: 12)

                HStack {
                    Text("CLEAR")
                        .font(.system(size: 8, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text("AMBIGUOUS")
                        .font(.system(size: 8, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Text("\(tones.count) active tones · summed Shannon entropy of JI-ratio guesses")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 24)
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

    /// Sum of pair entropies. Each pair's entropy is the Shannon entropy
    /// over a Gaussian-weighted distribution of "this cents value matches
    /// JI ratio X" probabilities, scaled by the product of amplitudes.
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
        for ratio in Self.jiRatios {
            let ratioCents = 1200 * log2(ratio)
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
