import Foundation

public enum TimeFrame: String, CaseIterable, Identifiable, Codable, Sendable {
    case year
    case moon
    case quarterMoon
    case day
    case hour
    case minute

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .year:        return "ONE YEAR"
        case .moon:        return "MOON CYCLE"
        case .quarterMoon: return "1/4 MOON"
        case .day:         return "ONE DAY"
        case .hour:        return "ONE HOUR"
        case .minute:      return "ONE MINUTE"
        }
    }

    public var sublabel: String {
        switch self {
        case .year:        return "~365.25 days"
        case .moon:        return "~29.53 days"
        case .quarterMoon: return "~7.38 days"
        case .day:         return "24 hours"
        case .hour:        return "60 minutes"
        case .minute:      return "60 seconds"
        }
    }

    public var availableInWidget: Bool { self != .minute }

    public var cycleDuration: TimeInterval {
        switch self {
        case .year:        return 365.25 * 24 * 60 * 60
        case .moon:        return MoonPhase.synodicMonthSeconds
        case .quarterMoon: return MoonPhase.synodicMonthSeconds / 4
        case .day:         return 24 * 60 * 60
        case .hour:        return 60 * 60
        case .minute:      return 60
        }
    }

    public func degree(at date: Date, calendar: Calendar = .current) -> Double {
        switch self {
        case .year:        return Self.yearDegree(at: date, calendar: calendar)
        case .moon:        return MoonPhase.moonDegree(at: date)
        case .quarterMoon: return MoonPhase.quarterMoonDegree(at: date)
        case .day:         return Self.dayDegree(at: date, calendar: calendar)
        case .hour:        return Self.hourDegree(at: date, calendar: calendar)
        case .minute:      return Self.minuteDegree(at: date, calendar: calendar)
        }
    }

    public func traditionalLabel(at date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents(
            [.year, .month, .day, .weekday, .hour, .minute, .second, .nanosecond],
            from: date
        )
        switch self {
        case .year:
            return String(comps.year ?? 0)
        case .moon:
            let m = max(1, min(12, comps.month ?? 1))
            return "\(Self.monthNames[m - 1]) \(comps.day ?? 0)"
        case .quarterMoon:
            let w = max(1, min(7, comps.weekday ?? 1))
            return Self.dayNames[w - 1]
        case .day:
            return String(format: "%02d:%02d:%02d", comps.hour ?? 0, comps.minute ?? 0, comps.second ?? 0)
        case .hour:
            return String(format: "%02d:%02d", comps.minute ?? 0, comps.second ?? 0)
        case .minute:
            let tenths = (comps.nanosecond ?? 0) / 100_000_000
            return String(format: "%02d.%d", comps.second ?? 0, tenths)
        }
    }

    private static let monthNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    private static let dayNames = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]

    private static func yearDegree(at date: Date, calendar: Calendar) -> Double {
        let comps = calendar.dateComponents([.year], from: date)
        guard let year = comps.year,
              let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return 0 }
        let elapsed = date.timeIntervalSince(yearStart)
        let total = yearEnd.timeIntervalSince(yearStart)
        return (elapsed / total) * 360
    }

    private static func dayDegree(at date: Date, calendar: Calendar) -> Double {
        let startOfDay = calendar.startOfDay(for: date)
        let elapsed = date.timeIntervalSince(startOfDay)
        return (elapsed / (24 * 60 * 60)) * 360
    }

    private static func hourDegree(at date: Date, calendar: Calendar) -> Double {
        let comps = calendar.dateComponents([.minute, .second, .nanosecond], from: date)
        let seconds = Double(comps.minute ?? 0) * 60
            + Double(comps.second ?? 0)
            + Double(comps.nanosecond ?? 0) / 1_000_000_000
        return (seconds / 3600) * 360
    }

    private static func minuteDegree(at date: Date, calendar: Calendar) -> Double {
        let comps = calendar.dateComponents([.second, .nanosecond], from: date)
        let seconds = Double(comps.second ?? 0)
            + Double(comps.nanosecond ?? 0) / 1_000_000_000
        return (seconds / 60) * 360
    }
}
