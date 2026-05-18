import SwiftUI

extension GeometryMath {
    /// Shared shape list used by both app and widget (3..8 divisions, with star polygons).
    public static let defaultShapes: [Shape] = buildShapeList(
        minDivisions: 3,
        maxDivisions: 8,
        includeStars: true
    )
}

/// Draws inscribed polygons / star polygons whose nodes "breathe" in and
/// out of view as the indicator dot sweeps past them.
public struct GeometryOverlayView: View {
    public let shapes: [GeometryMath.Shape]
    public let currentDegree: Double
    public let lineWidth: CGFloat
    public let strokeColor: Color
    public let fadeFraction: Double

    public init(
        shapes: [GeometryMath.Shape] = GeometryMath.defaultShapes,
        currentDegree: Double,
        lineWidth: CGFloat = 0.8,
        strokeColor: Color = .white,
        fadeFraction: Double = 0.03
    ) {
        self.shapes = shapes
        self.currentDegree = currentDegree
        self.lineWidth = lineWidth
        self.strokeColor = strokeColor
        self.fadeFraction = fadeFraction
    }

    public var body: some View {
        Canvas { context, size in
            drawShapes(in: &context, size: size)
        }
    }

    private func drawShapes(in context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        for shape in shapes {
            let opacity = FadeMath.shapeOpacity(
                currentDegree: currentDegree,
                divisions: shape.divisions,
                fadeFraction: fadeFraction
            )
            guard opacity > 0.001 else { continue }

            let points = Self.nodePoints(divisions: shape.divisions, center: center, radius: radius)
            let path = Self.makePath(edges: shape.path, points: points)
            let stroke = strokeColor.opacity(opacity * 0.85)
            context.stroke(path, with: .color(stroke), lineWidth: lineWidth)
        }
    }

    private static func nodePoints(divisions: Int, center: CGPoint, radius: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        points.reserveCapacity(divisions)
        for i in 0..<divisions {
            let degrees = Double(i) * 360.0 / Double(divisions) - 90
            let radians = degrees * .pi / 180
            let x = center.x + radius * CGFloat(cos(radians))
            let y = center.y + radius * CGFloat(sin(radians))
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    private static func makePath(edges: [GeometryMath.Edge], points: [CGPoint]) -> Path {
        var path = Path()
        for edge in edges {
            path.move(to: points[edge.from])
            path.addLine(to: points[edge.to])
        }
        return path
    }
}
