import Foundation

extension Calendar {
    /// A Gregorian calendar in `timeZone`. Month bucketing always uses one (see ``MonthKey``),
    /// whatever calendar system the device is set to.
    public static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
