import Foundation
import SwiftData

/// How much of the raw window History has loaded (D-053): whole months, from the current month back to
/// ``oldestLoaded``. The list starts with ``monthsPerPage`` months and loads the next page of older
/// months as you scroll, until it reaches the oldest month of the 13-month window (D-017).
///
/// Pages are whole months, so every loaded month's header total covers the full month.
public struct HistoryPages: Equatable, Sendable {
    /// Months loaded at first and added per page.
    public static let monthsPerPage = 2

    /// The current month: the newest month of the window. An entry dated after it (possible after a
    /// time-zone change, D-044) is still fetched and shown above it (D-057).
    public let latest: MonthKey
    /// The oldest month of the raw window, ``RetentionWindow/firstRawMonth(now:timeZone:)``.
    public let earliest: MonthKey
    /// The oldest month loaded so far, between ``earliest`` and ``latest``.
    public private(set) var oldestLoaded: MonthKey

    /// The first page: `current` and the month before it.
    public init(current: MonthKey) {
        self.init(current: current, oldestLoaded: current.adding(months: -(Self.monthsPerPage - 1)))
    }

    /// Pages whose newest month is `current`, loaded back to `oldestLoaded` (clamped into the window).
    public init(current: MonthKey, oldestLoaded: MonthKey) {
        latest = current
        earliest = current.adding(months: -RetentionWindow.monthsBeforeCurrent)
        self.oldestLoaded = min(max(oldestLoaded, earliest), current)
    }

    /// Whether older months of the window are still to load.
    public var hasMore: Bool { oldestLoaded > earliest }

    /// The loaded months, newest first.
    public var loadedMonths: [MonthKey] {
        var months: [MonthKey] = []
        var month = latest
        while month >= oldestLoaded {
            months.append(month)
            month = month.previous
        }
        return months
    }

    /// Loads the next ``monthsPerPage`` older months, stopping at ``earliest``. Does nothing once
    /// everything is loaded.
    public mutating func loadNextPage() {
        oldestLoaded = max(oldestLoaded.adding(months: -Self.monthsPerPage), earliest)
    }

    /// Loads the next page only while `oldest` is still ``oldestLoaded``. The list can ask for the same
    /// page twice (the end row came into view, and the loaded months were too few to fill the screen):
    /// passing the month it saw makes the second ask a no-op, so no page is skipped.
    public mutating func loadNextPage(after oldest: MonthKey) {
        if oldest == oldestLoaded { loadNextPage() }
    }

    /// The same pages after the current month changed (a new month started, or the time zone moved):
    /// the window slides to `current`, and the loaded months stay loaded as far as they're still inside it.
    public func moved(to current: MonthKey) -> HistoryPages {
        if current == latest { return self }
        let first = HistoryPages(current: current)
        return HistoryPages(current: current, oldestLoaded: min(oldestLoaded, first.oldestLoaded))
    }

    /// `[start of oldestLoaded, distant future)` in `timeZone`: the date range to fetch (D-018). Open-ended
    /// on purpose, so History never hides an entry dated in a later month: it appears at the top (D-057).
    /// Home and Analisis stay bounded by month.
    public func dateRange(in timeZone: TimeZone) -> Range<Date> {
        oldestLoaded.start(in: timeZone)..<Date.distantFuture
    }
}

extension MoneyTransaction {
    /// History's fetch: every transaction from the oldest loaded month on, including any dated after the
    /// current month (D-057), newest first (ties: newest entry first). Bounded below by the date range, so
    /// the `date` index applies (D-018). Also usable in a view's `@Query`.
    public static func historyDescriptor(_ pages: HistoryPages, timeZone: TimeZone) -> FetchDescriptor<MoneyTransaction> {
        descriptor(in: pages.dateRange(in: timeZone))
    }
}

extension Ledger {
    /// The transactions of History's loaded months and any later ones, newest first.
    public func historyTransactions(_ pages: HistoryPages) throws -> [MoneyTransaction] {
        try context.fetch(MoneyTransaction.historyDescriptor(pages, timeZone: timeZone))
    }
}
