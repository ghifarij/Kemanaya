import Foundation

/// The rolling raw-transaction window (D-017): this month plus the 12 months before it.
public enum RetentionWindow {
    /// Full months kept before the current one.
    public static let monthsBeforeCurrent = 12

    /// The oldest month whose raw transactions are still kept. Nov 2026 → Nov 2025.
    public static func firstRawMonth(now: Date, timeZone: TimeZone) -> MonthKey {
        MonthKey(containing: now, timeZone: timeZone).adding(months: -monthsBeforeCurrent)
    }

    /// `startOfMonth(now) − 12 months`. In Nov 2026 this is 1 Nov 2025, 00:00 local time.
    /// Transactions dated before it are rolled up and purged (Phase 8).
    public static func rawWindowStart(now: Date, timeZone: TimeZone) -> Date {
        firstRawMonth(now: now, timeZone: timeZone).start(in: timeZone)
    }

    /// The dates a transaction may be entered with (D-044): from ``rawWindowStart(now:timeZone:)`` through
    /// the last instant of the current month, both inclusive. Upcoming days of this month are allowed
    /// (planning is per month); later months are not.
    ///
    /// - Parameter existing: the date of a transaction being edited. If it is outside the window, the
    ///   range widens to include it, so an untouched edit never moves it. It can be older than the window
    ///   (until Phase 8 purges it) or after this month (e.g. recorded in a time zone ahead of this one).
    public static func entryDates(now: Date, timeZone: TimeZone, keeping existing: Date? = nil) -> ClosedRange<Date> {
        var start = rawWindowStart(now: now, timeZone: timeZone)
        var end = lastEntryInstant(now: now, timeZone: timeZone)
        if let existing {
            start = min(start, existing)
            end = max(end, existing)
        }
        return start...end
    }

    /// The first instant no entry may have: the start of next month (D-044). Dates before it are allowed.
    public static func entryLimit(now: Date, timeZone: TimeZone) -> Date {
        MonthKey(containing: now, timeZone: timeZone).next.start(in: timeZone)
    }

    /// `date` pulled into ``entryDates(now:timeZone:keeping:)``.
    public static func clampedEntryDate(_ date: Date, now: Date, timeZone: TimeZone, keeping existing: Date? = nil) -> Date {
        let range = entryDates(now: now, timeZone: timeZone, keeping: existing)
        return min(max(date, range.lowerBound), range.upperBound)
    }

    /// The last representable instant of the current month, just before ``entryLimit(now:timeZone:)``.
    private static func lastEntryInstant(now: Date, timeZone: TimeZone) -> Date {
        Date(timeIntervalSinceReferenceDate: entryLimit(now: now, timeZone: timeZone).timeIntervalSinceReferenceDate.nextDown)
    }
}
