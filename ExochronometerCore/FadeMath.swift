import Foundation

public enum FadeMath {
    /// Returns the shortest angular distance between two angles, in [0, 180].
    public static func circularDistance(_ a: Double, _ b: Double) -> Double {
        var diff = a - b
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        return abs(diff)
    }

    /// Cosine-eased opacity centered on `targetDegree`. fadeFraction is the
    /// half-window expressed as a fraction of 360° (0.03 = 10.8° window).
    public static func opacity(
        currentDegree: Double,
        targetDegree: Double,
        fadeFraction: Double = 0.03
    ) -> Double {
        let fadeWindow = fadeFraction * 360
        let dist = circularDistance(currentDegree, targetDegree)
        if dist > fadeWindow { return 0 }
        return cos((dist / fadeWindow) * (.pi / 2))
    }

    /// Best opacity across all `divisions` evenly-spaced nodes.
    public static func shapeOpacity(
        currentDegree: Double,
        divisions: Int,
        fadeFraction: Double = 0.03
    ) -> Double {
        var best = 0.0
        for i in 0..<divisions {
            let nodeDeg = Double(i) * 360.0 / Double(divisions)
            let op = opacity(
                currentDegree: currentDegree,
                targetDegree: nodeDeg,
                fadeFraction: fadeFraction
            )
            if op > best { best = op }
        }
        return best
    }
}
