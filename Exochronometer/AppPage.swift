import Foundation

enum AppPage: String, CaseIterable, Identifiable {
    case circles
    case timeline
    case geometryHarmonics
    case harmonicAnalysis
    case spatialAnalysis
    case peakCalendar
    case misc

    var id: String { rawValue }

    var label: String {
        switch self {
        case .circles:           return "Circles"
        case .timeline:          return "Timeline"
        case .geometryHarmonics: return "Geometry Harmonics"
        case .harmonicAnalysis:  return "Harmonic Analysis"
        case .spatialAnalysis:   return "Spatial Analysis"
        case .peakCalendar:      return "Peak Calendar"
        case .misc:              return "Misc"
        }
    }
}
