import Foundation

public struct HarmonicTone: Identifiable, Hashable {
    public let timeframe: TimeFrame
    public let divisions: Int       // 1 for the fundamental, 3..8 for overtones
    public let scaling: Int         // octaves of 2 by which the natural frequency is shifted
    public let frequency: Double    // scaled frequency in Hz
    public let amplitude: Double    // 0..1

    public init(
        timeframe: TimeFrame,
        divisions: Int,
        scaling: Int,
        frequency: Double,
        amplitude: Double
    ) {
        self.timeframe = timeframe
        self.divisions = divisions
        self.scaling = scaling
        self.frequency = frequency
        self.amplitude = amplitude
    }

    public var id: String { "\(timeframe.rawValue)-\(divisions)-\(scaling)" }
    public var isFundamental: Bool { divisions == 1 }
}

public enum HarmonicAnalysis {
    /// All currently-active tones at one or more octave scalings.
    /// Fundamentals are always returned at amplitude 1.0. Overtones for
    /// divisions 3..8 are returned only when their `FadeMath.shapeOpacity`
    /// is above `threshold`. The minute timeframe is excluded.
    public static func activeTones(
        at date: Date,
        scales: [Int],
        threshold: Double = 0.01
    ) -> [HarmonicTone] {
        var out: [HarmonicTone] = []
        for sc in scales {
            let factor = pow(2.0, Double(sc))
            for tf in TimeFrame.allCases where tf != .minute {
                let fundamental = (1.0 / tf.cycleDuration) * factor
                let degree = tf.degree(at: date)

                out.append(HarmonicTone(
                    timeframe: tf,
                    divisions: 1,
                    scaling: sc,
                    frequency: fundamental,
                    amplitude: 1.0
                ))

                for div in 3...8 {
                    let amp = FadeMath.shapeOpacity(currentDegree: degree, divisions: div)
                    if amp > threshold {
                        out.append(HarmonicTone(
                            timeframe: tf,
                            divisions: div,
                            scaling: sc,
                            frequency: fundamental * Double(div),
                            amplitude: amp
                        ))
                    }
                }
            }
        }
        return out
    }
}
