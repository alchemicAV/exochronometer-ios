import Foundation

public enum MoonPhase {
    public static let referenceNewMoon: Date = {
        var comps = DateComponents()
        comps.year = 2000
        comps.month = 1
        comps.day = 6
        comps.hour = 18
        comps.minute = 14
        comps.timeZone = TimeZone(identifier: "UTC")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: comps) ?? Date(timeIntervalSince1970: 947182440)
    }()

    public static let synodicMonthDays: Double = 29.530588853
    public static var synodicMonthSeconds: Double { synodicMonthDays * 24 * 60 * 60 }
    public static var quarterMoonSeconds: Double { synodicMonthSeconds / 4 }

    public static func phase(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(referenceNewMoon)
        let m = elapsed / synodicMonthSeconds
        return m - floor(m)
    }

    public static func moonDegree(at date: Date) -> Double {
        phase(at: date) * 360
    }

    public static func quarterMoonDegree(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(referenceNewMoon)
        let m = elapsed / quarterMoonSeconds
        return (m - floor(m)) * 360
    }

    public static func phaseName(forPhase phase: Double) -> String {
        switch phase {
        case ..<0.0625: return "New Moon"
        case ..<0.1875: return "Waxing Crescent"
        case ..<0.3125: return "First Quarter"
        case ..<0.4375: return "Waxing Gibbous"
        case ..<0.5625: return "Full Moon"
        case ..<0.6875: return "Waning Gibbous"
        case ..<0.8125: return "Last Quarter"
        case ..<0.9375: return "Waning Crescent"
        default:        return "New Moon"
        }
    }
}
