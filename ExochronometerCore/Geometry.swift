import Foundation

public enum GeometryMath {

    public static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = abs(a)
        var b = abs(b)
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }

    public struct Edge: Hashable, Sendable {
        public let from: Int
        public let to: Int
        public init(from: Int, to: Int) {
            self.from = from
            self.to = to
        }
    }

    public struct Shape: Hashable, Identifiable, Sendable {
        public let divisions: Int
        public let skip: Int
        public let path: [Edge]
        public let isRegular: Bool
        public var nodeSpacing: Double { 360.0 / Double(divisions) }
        public var id: String { "\(divisions)-\(skip)" }
    }

    public static func generateShapePath(divisions: Int, skip: Int) -> [Edge] {
        var path: [Edge] = []
        var visited: Set<Int> = []
        for start in 0..<divisions {
            if visited.contains(start) { continue }
            var current = start
            while !visited.contains(current) {
                visited.insert(current)
                let next = (current + skip) % divisions
                path.append(Edge(from: current, to: next))
                current = next
            }
        }
        return path
    }

    public static func buildShapeList(
        minDivisions: Int = 3,
        maxDivisions: Int = 12,
        includeStars: Bool = true
    ) -> [Shape] {
        var shapes: [Shape] = []
        guard minDivisions <= maxDivisions else { return shapes }
        for div in minDivisions...maxDivisions {
            for skip in 1..<div {
                if Double(skip) >= Double(div) / 2 { continue }
                if gcd(div, skip) != 1 { continue }
                let isReg = (skip == 1)
                if !includeStars && !isReg { continue }
                shapes.append(Shape(
                    divisions: div,
                    skip: skip,
                    path: generateShapePath(divisions: div, skip: skip),
                    isRegular: isReg
                ))
            }
        }
        return shapes
    }

    public static func nodeDegrees(divisions: Int) -> [Double] {
        (0..<divisions).map { Double($0) * 360.0 / Double(divisions) }
    }
}
