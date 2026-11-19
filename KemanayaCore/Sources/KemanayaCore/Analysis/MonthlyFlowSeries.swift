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
    public init(
        _ transactions: some Sequence<TransactionSnapshot>,
        ending selected: MonthKey,
        length: Int = defaultLength,
        timeZone: TimeZone
    ) {
        let keys = Self.months(ending: selected, length: length)
        var expenses: [MonthKey: Int64] = [:]
        var income: [MonthKey: Int64] = [:]
        let span = Self.dateRange(ending: selected, length: length, timeZone: timeZone)
        for transaction in transactions where span.contains(transaction.date) {
            let month = MonthKey(containing: transaction.date, timeZone: timeZone)
            switch (transaction.kind, transaction.group) {
            case (.income, _): income[month, default: 0] += transaction.amount
            case (.expense, .some): expenses[month, default: 0] += transaction.amount
            // An expense without a group can't exist (D-003); skipped as in ``MonthSummary``.
            case (.expense, nil): continue
            }
        }
        self.selected = selected
        self.months = keys.map { MonthlyFlow(month: $0, expenses: expenses[$0] ?? 0, income: income[$0] ?? 0) }
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
