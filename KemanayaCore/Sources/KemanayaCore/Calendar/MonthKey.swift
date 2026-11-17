import Foundation

/// A Gregorian calendar month, e.g. November 2026. The unit every screen, total and rollup is bucketed by.
///
/// Date conversions take a `TimeZone`, not a `Calendar`: the calendar is always Gregorian, so a device
/// set to another calendar system (e.g. Buddhist, year 2569) can never persist a wrong `yyyymm`.
public struct MonthKey: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    /// `1...12`.
    public let month: Int

    /// - Precondition: `month` is in `1...12`.
    public init(year: Int, month: Int) {
        precondition((1...12).contains(month), "month must be 1...12, got \(month)")
        self.year = year
        self.month = month
    }

    /// The month that contains `date`, in `timeZone`. The app passes `.autoupdatingCurrent` (D-017).
    public init(containing date: Date, timeZone: TimeZone) {
        let components = Calendar.gregorian(in: timeZone).dateComponents([.year, .month], from: date)
        self.init(year: components.year!, month: components.month!)
    }

    /// `yyyymm`, e.g. `202611`. Sorts like the months; persisted in ``MonthlyRollup/monthKey``.
    public var rawValue: Int { year * 100 + month }

    /// Reads a `yyyymm` value. Nil when the month part is not `1...12`.
    public init?(rawValue: Int) {
        let month = rawValue % 100
        guard (1...12).contains(month) else { return nil }
        self.init(year: rawValue / 100, month: month)
    }

    /// The month `count` months later (negative = earlier). Crosses year boundaries.
    public func adding(months count: Int) -> MonthKey {
        let index = year * 12 + (month - 1) + count
        var (newYear, monthIndex) = index.quotientAndRemainder(dividingBy: 12)
        if monthIndex < 0 {
            // Floor division, so years before 0 still work.
            newYear -= 1
            monthIndex += 12
        }
        return MonthKey(year: newYear, month: monthIndex + 1)
    }

    public var next: MonthKey { adding(months: 1) }
    public var previous: MonthKey { adding(months: -1) }

    /// The first instant of this month in `timeZone`.
    public func start(in timeZone: TimeZone) -> Date {
        Calendar.gregorian(in: timeZone).date(from: DateComponents(year: year, month: month, day: 1))!
    }

    /// `[start of this month, start of next month)` in `timeZone`.
    /// Use it for date-range fetches (D-018): `date >= lowerBound && date < upperBound`.
    public func dateRange(in timeZone: TimeZone) -> Range<Date> {
        start(in: timeZone)..<next.start(in: timeZone)
    }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// `2026-11`. For logs and test output, never for UI.
    public var description: String {
        String(format: "%04d-%02d", year, month)
    }
}
