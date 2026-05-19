import SwiftUI
import ExochronometerCore

struct GeometryHarmonicsPage: View {
    @State private var selectedTimeframe: TimeFrame = .day

    private let shapes: [GeometryMath.Shape] = GeometryMath.defaultShapes

    var body: some View {
        VStack(spacing: 14) {
            timeframeSelector
                .padding(.top, 4)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(shapes) { shape in
                        HarmonicRow(shape: shape, timeframe: selectedTimeframe)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimeFrame.allCases) { tf in
                    Button {
                        selectedTimeframe = tf
                    } label: {
                        Text(tf.label)
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(selectedTimeframe == tf ? .black : .white.opacity(0.7))
                            .background(
                                Capsule()
                                    .fill(selectedTimeframe == tf ? Color.white : .clear)
                            )
                            .overlay(
                                Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct HarmonicRow: View {
    let shape: GeometryMath.Shape
    let timeframe: TimeFrame

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.35), lineWidth: 0.6)
                PolygonView(shape: shape)
                    .padding(2)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(shape.divisions):1")
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(shapeName)
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text("period: \(periodString)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Text("interval: \(intervalString)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)
        }
    }

    private var harmonicPeriodSeconds: Double {
        timeframe.cycleDuration / Double(shape.divisions)
    }

    private var periodString: String {
        FrequencyMath.formatDuration(harmonicPeriodSeconds)
    }

    private var intervalString: String {
        switch shape.divisions {
        case 2: return "Octave (2:1)"
        case 3: return "Perfect Fifth (3:2)"
        case 4: return "Octave (4:1)"
        case 5: return "Major Third (5:4)"
        case 6: return "Perfect Fifth (6:4)"
        case 7: return "Harmonic Seventh (7:4)"
        case 8: return "Octave (8:1)"
        case 9: return "Major Second (9:8)"
        case 10: return "Major Third (10:8)"
        case 11: return "Undecimal Tritone (11:8)"
        case 12: return "Perfect Fifth (12:8)"
        default: return "\(shape.divisions):1"
        }
    }

    private var shapeName: String {
        switch (shape.divisions, shape.skip) {
        case (3, 1): return "TRIANGLE"
        case (4, 1): return "SQUARE"
        case (5, 1): return "PENTAGON"
        case (5, 2): return "PENTAGRAM"
        case (6, 1): return "HEXAGON"
        case (7, 1): return "HEPTAGON"
        case (7, 2): return "HEPTAGRAM {7/2}"
        case (7, 3): return "HEPTAGRAM {7/3}"
        case (8, 1): return "OCTAGON"
        case (8, 3): return "OCTAGRAM"
        default:     return "{\(shape.divisions)/\(shape.skip)}"
        }
    }
}

private struct PolygonView: View {
    let shape: GeometryMath.Shape

    var body: some View {
        Canvas { ctx, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let points = nodePoints(divisions: shape.divisions, center: center, radius: radius)
            let path = makePath(edges: shape.path, points: points)
            ctx.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1)
        }
    }

    private func nodePoints(divisions: Int, center: CGPoint, radius: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        points.reserveCapacity(divisions)
        for i in 0..<divisions {
            let degrees = Double(i) * 360.0 / Double(divisions) - 90
            let radians = degrees * .pi / 180
            points.append(CGPoint(
                x: center.x + radius * CGFloat(cos(radians)),
                y: center.y + radius * CGFloat(sin(radians))
            ))
        }
        return points
    }

    private func makePath(edges: [GeometryMath.Edge], points: [CGPoint]) -> Path {
        var path = Path()
        for edge in edges {
            path.move(to: points[edge.from])
            path.addLine(to: points[edge.to])
        }
        return path
    }
}
