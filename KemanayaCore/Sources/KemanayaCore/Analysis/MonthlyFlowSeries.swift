import Foundation

/// One month of the month-over-month chart: what went out and what came in.
public struct MonthlyFlow: Equatable, Sendable, Identifiable {
    public let month: MonthKey
    /// Kebutuhan + Keinginan, rupiah.
    public let expenses: Int64
    /// Pemasukan, rupiah.
    public let income: Int64

    public init(month: MonthKey, expenses: Int64, income: Int64) {
        self.month = month
        self.expenses = expenses
        self.income = income
    }

    public var id: MonthKey { month }
}

/// Pengeluaran and pemasukan for the months ending at the selected one (D-051), for paired bars.
/// It shows the totals, not the group filter: income has no group, so a filtered pair would compare
/// part of the spending with all of the income.
public struct MonthlyFlowSeries: Equatable, Sendable {
    /// Six months: the selected one and the five before it.
    public static let defaultLength = 6

    /// The highlighted month, always the last one.
    public let selected: MonthKey
    /// Oldest first, ending at ``selected``; months without transactions are present with zeros.
    public let months: [MonthlyFlow]

    /// - Parameter transactions: any transactions; only those dated in the series' months count.
    ///   Raw only: months before the raw window read zero here, so screens use ``init(totals:ending:length:)``.
    public init(
        _ transactions: some Sequence<TransactionSnapshot>,
        ending selected: MonthKey,
        length: Int = defaultLength,
        timeZone: TimeZone
    ) {
        self.init(
            totals: MonthTotals(transactions: transactions, rollups: EmptyCollection<RollupSnapshot>(), timeZone: timeZone),
            ending: selected,
            length: length
        )
    }

    /// The series from ``MonthTotals`` (D-055): rollups for months before the raw window, so a purged
    /// month shows its real totals instead of a false Rp0.
    public init(totals: MonthTotals, ending selected: MonthKey, length: Int = defaultLength) {
        self.selected = selected
        self.months = Self.months(ending: selected, length: length).map { month in
            let summary = totals.summary(for: month)
            return MonthlyFlow(month: month, expenses: summary.expenses, income: summary.income)
        }
    }

    /// The months of a series, oldest first. A length below 1 counts as 1.
    public static func months(ending selected: MonthKey, length: Int = defaultLength) -> [MonthKey] {
        let count = max(length, 1)
        return (0..<count).map { selected.adding(months: $0 - count + 1) }
    }

    /// The fetch range for a series (D-018): the first instant of its oldest month up to the start of
    /// the month after `selected`.
    public static func dateRange(ending selected: MonthKey, length: Int = defaultLength, timeZone: TimeZone) -> Range<Date> {
        let first = months(ending: selected, length: length)[0]
        return first.start(in: timeZone)..<selected.next.start(in: timeZone)
    }

    /// The tallest bar, for the chart's scale; 0 when every month is empty.
    public var largestAmount: Int64 {
        months.map { max($0.expenses, $0.income) }.max() ?? 0
    }

    /// No money moved in any of the months: the chart gives way to an empty note.
    public var isEmpty: Bool { largestAmount == 0 }
}
