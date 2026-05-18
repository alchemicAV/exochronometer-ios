import AppIntents
import ExochronometerCore

enum WidgetTimeframe: String, AppEnum {
    case year
    case moon
    case quarterMoon
    case day
    case hour

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timeframe"
    static var caseDisplayRepresentations: [WidgetTimeframe: DisplayRepresentation] = [
        .year:        "One Year",
        .moon:        "Moon Cycle",
        .quarterMoon: "Quarter Moon",
        .day:         "One Day",
        .hour:        "One Hour",
    ]

    var timeFrame: TimeFrame {
        switch self {
        case .year:        return .year
        case .moon:        return .moon
        case .quarterMoon: return .quarterMoon
        case .day:         return .day
        case .hour:        return .hour
        }
    }
}

struct TimeframeConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Timeframe"
    static var description = IntentDescription("Pick which time cycle this widget displays.")

    @Parameter(title: "Timeframe", default: .day)
    var timeframe: WidgetTimeframe

    init() {}

    init(timeframe: WidgetTimeframe) {
        self.timeframe = timeframe
    }
}
