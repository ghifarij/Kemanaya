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
}
