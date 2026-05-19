import SwiftUI
import ExochronometerCore

struct HarmonicAnalysisPage: View {
    private let octaves: Int = 26
    private let minFreqHz: Double = 1
    private let maxFreqHz: Double = 50_000

    var body: some View {
        VStack(spacing: 12) {
            header

            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                FourierSpectrumView(
                    date: context.date,
                    octaves: octaves,
                    minFreqHz: minFreqHz,
                    maxFreqHz: maxFreqHz
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)

            legend
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HARMONIC SPECTRUM")
                .font(.system(size: 10, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.6))
            Text("× 2^\(octaves)  ·  minute excluded")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var legend: some View {
        let factor = pow(2.0, Double(octaves))
        let fundamentals = TimeFrame.allCases
            .filter { $0 != .minute }
            .map { tf -> (String, Double) in
                (tf.label, (1.0 / tf.cycleDuration) * factor)
            }

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(fundamentals, id: \.0) { name, hz in
                HStack {
                    Text(name)
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 110, alignment: .leading)
                    Text(FrequencyMath.format(hz))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
            }
        }
    }
}

private struct FourierSpectrumView: View {
    let date: Date
    let octaves: Int
    let minFreqHz: Double
    let maxFreqHz: Double

    var body: some View {
        Canvas { ctx, size in
            drawSpectrum(in: &ctx, size: size)
        }
    }

    private func drawSpectrum(in ctx: inout GraphicsContext, size: CGSize) {
        let logMin = log10(minFreqHz)
        let logMax = log10(maxFreqHz)
        let range = logMax - logMin
        guard range > 0 else { return }

        drawAudibleBand(in: &ctx, size: size, logMin: logMin, range: range)
        drawGrid(in: &ctx, size: size, logMin: logMin, range: range)
        drawAxisLabels(in: &ctx, size: size, logMin: logMin, range: range)
        drawTones(in: &ctx, size: size, logMin: logMin, range: range)
    }

    private func drawAudibleBand(in ctx: inout GraphicsContext, size: CGSize, logMin: Double, range: Double) {
        let lo = mapX(20, logMin: logMin, range: range, width: size.width)
        let hi = mapX(20_000, logMin: logMin, range: range, width: size.width)
        let band = CGRect(x: lo, y: 0, width: hi - lo, height: size.height)
        ctx.fill(Path(band), with: .color(.white.opacity(0.04)))
    }

    private func drawGrid(in ctx: inout GraphicsContext, size: CGSize, logMin: Double, range: Double) {
        let decades: [Double] = [1, 10, 100, 1_000, 10_000]
        for d in decades {
            let x = mapX(d, logMin: logMin, range: range, width: size.width)
            var p = Path()
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: size.height))
            ctx.stroke(p, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
        }
        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: size.height - 0.5))
        baseline.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
        ctx.stroke(baseline, with: .color(.white.opacity(0.25)), lineWidth: 0.5)
    }

    private func drawAxisLabels(in ctx: inout GraphicsContext, size: CGSize, logMin: Double, range: Double) {
        let entries: [(Double, String)] = [
            (1, "1 Hz"),
            (10, "10"),
            (100, "100"),
            (1_000, "1k"),
            (10_000, "10k"),
        ]
        for (hz, label) in entries {
            let x = mapX(hz, logMin: logMin, range: range, width: size.width)
            let text = Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            ctx.draw(text, at: CGPoint(x: x, y: size.height - 8), anchor: .center)
        }
    }

    private func drawTones(in ctx: inout GraphicsContext, size: CGSize, logMin: Double, range: Double) {
        let factor = pow(2.0, Double(octaves))
        let plotHeight = size.height - 16

        for tf in TimeFrame.allCases where tf != .minute {
            let fundamental = (1.0 / tf.cycleDuration) * factor
            let degree = tf.degree(at: date)

            drawPeak(
                in: &ctx,
                size: size,
                freq: fundamental,
                amplitude: 1.0,
                color: .white,
                lineWidth: 1.5,
                logMin: logMin,
                range: range,
                plotHeight: plotHeight
            )

            for div in 3...8 {
                let amp = FadeMath.shapeOpacity(currentDegree: degree, divisions: div)
                if amp > 0.01 {
                    drawPeak(
                        in: &ctx,
                        size: size,
                        freq: fundamental * Double(div),
                        amplitude: amp,
                        color: .white.opacity(0.85),
                        lineWidth: 0.8,
                        logMin: logMin,
                        range: range,
                        plotHeight: plotHeight
                    )
                }
            }
        }
    }

    private func drawPeak(
        in ctx: inout GraphicsContext,
        size: CGSize,
        freq: Double,
        amplitude: Double,
        color: Color,
        lineWidth: Double,
        logMin: Double,
        range: Double,
        plotHeight: Double
    ) {
        guard freq >= minFreqHz, freq <= maxFreqHz else { return }
        let x = mapX(freq, logMin: logMin, range: range, width: size.width)
        let yBase = size.height - 8
        let yTop = yBase - plotHeight * amplitude

        var stem = Path()
        stem.move(to: CGPoint(x: x, y: yBase))
        stem.addLine(to: CGPoint(x: x, y: yTop))
        ctx.stroke(stem, with: .color(color), lineWidth: lineWidth)

        let dotR = 2.0 + amplitude * 2.0
        let dotRect = CGRect(
            x: x - dotR,
            y: yTop - dotR,
            width: dotR * 2,
            height: dotR * 2
        )
        ctx.fill(Path(ellipseIn: dotRect), with: .color(color))
    }

    private func mapX(_ freq: Double, logMin: Double, range: Double, width: Double) -> Double {
        ((log10(freq) - logMin) / range) * width
    }
}
