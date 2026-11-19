import Foundation

/// The months the Analisis stepper can show (D-051): from the current month back through the oldest
/// month of the raw-transaction window (D-017), 13 months in all. Older months hold only rollups
/// after Phase 8 purges them, so they have no transactions to break down.
public struct AnalysisMonthRange: Equatable, Sendable {
    /// The oldest month, ``RetentionWindow/firstRawMonth(now:timeZone:)``.
    public let earliest: MonthKey
    /// The current month. Later months can't hold entries (D-044), so the stepper stops here.
    public let latest: MonthKey

    /// The range whose newest month is `current`.
    public init(current: MonthKey) {
        self.latest = current
        self.earliest = current.adding(months: -RetentionWindow.monthsBeforeCurrent)
    }

    public func contains(_ month: MonthKey) -> Bool {
        earliest <= month && month <= latest
    }

    /// `month` pulled into the range.
    public func clamped(_ month: MonthKey) -> MonthKey {
        min(max(month, earliest), latest)
    }

    /// The month the stepper's ‹ goes to, or nil at ``earliest`` (the button is then disabled).
    public func month(before month: MonthKey) -> MonthKey? {
        let target = clamped(month).previous
        return contains(target) ? target : nil
    }

    /// The month the stepper's › goes to, or nil at ``latest``.
    public func month(after month: MonthKey) -> MonthKey? {
        let target = clamped(month).next
        return contains(target) ? target : nil
    }

    /// The month to show after the range moved from `old` to this one (a new month started, or the
    /// time zone changed): a selection on the old current month follows to the new current month, and
    /// any other selection stays put unless it dropped out of the window.
    public func carrying(_ selected: MonthKey, from old: AnalysisMonthRange) -> MonthKey {
        selected == old.latest ? latest : clamped(selected)
    }
}
