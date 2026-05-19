import Foundation

enum AppPage: String, CaseIterable, Identifiable {
    case circles
    case timeline
    case geometryHarmonics
    case harmonicAnalysis

    var id: String { rawValue }

    var label: String {
        switch self {
        case .circles:           return "Circles"
        case .timeline:          return "Timeline"
        case .geometryHarmonics: return "Geometry Harmonics"
        case .harmonicAnalysis:  return "Harmonic Analysis"
        }
    }
}
