import Foundation

/// The one answer to "what are the totals of month X?" (D-055, D-059), whether X is inside the raw
/// window (D-017) or before it.
///
/// Inside the window a month has raw transactions and no rollups: retention only rolls up months before
/// the window, and the window only moves forward. Before the window a month has rollups and, once
/// retention has run, no raw transactions. So the totals of a month are **its rollups plus its raw
/// transactions**: in every consistent store that is "raw inside the window, rollups outside it", and a
/// month caught between the two (the window just moved and retention hasn't run yet, or a restore brought
/// both) still reads what retention would leave, because retention *adds* raw totals into existing
/// rollups. No month before the window reads a false Rp0 while its rollups exist.
///
/// Built from plain values, so it's tested without SwiftData. Views feed it their `@Query` results
/// (transactions by date range, rollups by ``MonthlyRollup/predicate(from:through:)``); code that isn't a
/// view gets it from ``Ledger/monthTotals(from:through:)``.
public struct MonthTotals: Sendable {
    /// The zone transactions are bucketed into months in (D-017).
    public let timeZone: TimeZone
    private let transactionsByMonth: [MonthKey: [TransactionSnapshot]]
    private let rollupsByMonth: [MonthKey: [RollupSnapshot]]

    /// - Parameters:
    ///   - transactions: any transactions; each counts toward the month that contains its date in `timeZone`.
    ///   - rollups: any rollups; each counts toward its own month.
    public init(
        transactions: some Sequence<TransactionSnapshot>,
        rollups: some Sequence<RollupSnapshot>,
        timeZone: TimeZone
    ) {
        self.timeZone = timeZone
        self.transactionsByMonth = Dictionary(grouping: transactions) { MonthKey(containing: $0.date, timeZone: timeZone) }
        self.rollupsByMonth = Dictionary(grouping: rollups, by: \.month)
    }

    /// The month's totals: per group, income, and per subcategory (``MonthSummary``). Empty when the
    /// month has neither transactions nor rollups (or wasn't in what was fetched).
    public func summary(for month: MonthKey) -> MonthSummary {
        MonthSummary(transactionsByMonth[month] ?? [], rollups: rollupsByMonth[month] ?? [])
    }

    /// The months with any transaction or rollup, oldest first.
    public var months: [MonthKey] {
        Set(transactionsByMonth.keys).union(rollupsByMonth.keys).sorted()
    }

    /// The month's rollups as stored, for their name and emoji snapshots.
    public func rollups(in month: MonthKey) -> [RollupSnapshot] {
        rollupsByMonth[month] ?? []
    }
}
