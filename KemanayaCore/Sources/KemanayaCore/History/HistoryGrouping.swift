import Foundation

/// What History needs from a transaction to group, total and filter it (D-053, D-074). ``MoneyTransaction`` (the
/// screen's rows) and ``TransactionSnapshot`` (tests, plain values) both conform.
public protocol HistoryEntry {
    /// Rupiah, > 0 (D-016).
    var amount: Int64 { get }
    var kind: TransactionKind { get }
    /// The expense group, nil for income (D-005). Riwayat's filter reads it (D-074).
    var group: ExpenseGroup? { get }
    /// The subcategory's id, for Riwayat's filter (D-074).
    var subcategoryID: UUID { get }
    var date: Date { get }
}

extension MoneyTransaction: HistoryEntry {}
extension TransactionSnapshot: HistoryEntry {}

/// A Gregorian calendar day, e.g. Thursday 19 November 2026: the unit of History's sticky day headers.
/// Like ``MonthKey``, date conversions take a `TimeZone` and always use the Gregorian calendar.
public struct DayKey: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    /// `1...12`.
    public let month: Int
    /// `1...31`.
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day that contains `date`, in `timeZone` (the app passes the device zone, D-017).
    public init(containing date: Date, timeZone: TimeZone) {
        self.init(containing: date, calendar: .gregorian(in: timeZone))
    }

    /// The day that contains `date` in `calendar`, which must be ``Calendar/gregorian(in:)``. Lets a loop
    /// over many dates build the calendar once.
    public init(containing date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    /// The month this day is in.
    public var monthKey: MonthKey { MonthKey(year: year, month: month) }

    /// The first instant of this day in `timeZone`, for formatting its header ("Kamis, 19 Nov").
    public func start(in timeZone: TimeZone) -> Date {
        Calendar.gregorian(in: timeZone).date(from: DateComponents(year: year, month: month, day: day))!
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// `2026-11-19`. For logs and test output, never for UI.
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

/// Money out and money in over a month of History. Kept apart on purpose: the month header shows them
/// as two labelled figures, Pengeluaran and Pemasukan (D-053, D-073, D-022). They are never netted.
public struct HistoryTotals: Equatable, Sendable {
    /// Pengeluaran: the sum of expense amounts.
    public var expenses: Int64
    /// Pemasukan: the sum of income amounts.
    public var income: Int64

    public init(expenses: Int64 = 0, income: Int64 = 0) {
        self.expenses = expenses
        self.income = income
    }

    /// Adds one entry by its kind. Every expense counts, whatever its group, so the header always
    /// equals the sum of the rows under it.
    mutating func add(_ entry: some HistoryEntry) {
        switch entry.kind {
        case .expense: expenses += entry.amount
        case .income: income += entry.amount
        }
    }

    /// Whether the month has any income, so its header shows the Pemasukan figure.
    public var hasIncome: Bool { income > 0 }
}

/// One day of History: its entries in the order given. Its header shows the date only (D-073).
public struct HistoryDay<Entry: HistoryEntry>: Identifiable {
    public let day: DayKey
    /// In input order: the screen's fetch sorts newest first.
    public let entries: [Entry]

    public var id: DayKey { day }
}

/// One month of History: its days, newest first, and the month's totals.
public struct HistoryMonth<Entry: HistoryEntry>: Identifiable {
    public let month: MonthKey
    public let days: [HistoryDay<Entry>]
    public let totals: HistoryTotals

    public var id: MonthKey { month }
}

extension HistoryDay: Equatable where Entry: Equatable {}
extension HistoryDay: Sendable where Entry: Sendable {}
extension HistoryMonth: Equatable where Entry: Equatable {}
extension HistoryMonth: Sendable where Entry: Sendable {}

/// Groups History's entries into months, with their totals, and days (D-053, D-073).
public enum HistoryGrouping {
    /// `entries` grouped by month, with the month's totals, then by day, both newest first. Days are
    /// Gregorian days in `timeZone`. Within a day, entries keep their input order, so pass them newest
    /// first (``MoneyTransaction/descriptor(in:filter:)`` sorts that way). Months and days without
    /// entries are left out, so search results keep the day grouping with only the matching days.
    /// Entries dated after the current month (possible after a time-zone change, D-044, D-057) group into
    /// their own month, which sorts first.
    ///
    /// One pass over `entries`, so a lazily filtered sequence (search results) is grouped without an
    /// intermediate array.
    public static func months<Entry: HistoryEntry>(_ entries: some Sequence<Entry>, timeZone: TimeZone) -> [HistoryMonth<Entry>] {
        let calendar = Calendar.gregorian(in: timeZone)
        var byDay: [DayKey: [Entry]] = [:]
        var monthTotals: [MonthKey: HistoryTotals] = [:]
        for entry in entries {
            let day = DayKey(containing: entry.date, calendar: calendar)
            byDay[day, default: []].append(entry)
            monthTotals[day.monthKey, default: HistoryTotals()].add(entry)
        }
        var byMonth: [MonthKey: [HistoryDay<Entry>]] = [:]
        for (day, dayEntries) in byDay {
            byMonth[day.monthKey, default: []].append(HistoryDay(day: day, entries: dayEntries))
        }
        return byMonth
            .map { month, days in
                HistoryMonth(month: month, days: days.sorted { $0.day > $1.day }, totals: monthTotals[month] ?? HistoryTotals())
            }
            .sorted { $0.month > $1.month }
    }
}
