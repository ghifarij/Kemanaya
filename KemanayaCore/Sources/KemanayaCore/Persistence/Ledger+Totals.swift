import Foundation
import SwiftData

/// Month totals that reach before the raw window (D-055, D-059) and the yearly recap. Views get the same
/// numbers live from `@Query` results through ``MonthTotals`` and ``YearRecap``; these fetch them once.
extension Ledger {
    /// The totals of the months `first` through `last`: raw transactions by date range (D-018) plus the
    /// rollups of those months (``MonthTotals``).
    public func monthTotals(from first: MonthKey, through last: MonthKey) throws -> MonthTotals {
        let range = first.start(in: timeZone)..<last.next.start(in: timeZone)
        let transactions = try context.fetch(MoneyTransaction.descriptor(in: range)).map(TransactionSnapshot.init)
        let rollups = try context.fetch(MonthlyRollup.descriptor(from: first, through: last)).compactMap(RollupSnapshot.init)
        return MonthTotals(transactions: transactions, rollups: rollups, timeZone: timeZone)
    }

    /// The oldest month with a transaction or a rollup, or nil when the store has neither.
    /// Two single-row fetches by index.
    public func earliestMonthWithData() throws -> MonthKey? {
        let transaction = try context.fetch(MoneyTransaction.earliestDescriptor).first
            .map { MonthKey(containing: $0.date, timeZone: timeZone) }
        let rollup = try context.fetch(MonthlyRollup.earliestDescriptor).first?.month
        return [transaction, rollup].compactMap(\.self).min()
    }

    /// The recap of `year` (D-059), with current subcategory names where the subcategory still exists.
    /// - Parameter now: decides the current month, so whether `year` is year to date.
    public func yearRecap(for year: Int, now: Date = .now) throws -> YearRecap {
        let range = YearRecap.dateRange(of: year, timeZone: timeZone)
        let transactions = try context.fetch(MoneyTransaction.descriptor(in: range)).map(TransactionSnapshot.init)
        let rollups = try context.fetch(
            MonthlyRollup.descriptor(from: MonthKey(year: year, month: 1), through: MonthKey(year: year, month: 12))
        ).compactMap(RollupSnapshot.init)
        let labels = try context.fetch(FetchDescriptor<Subcategory>()).reduce(into: [UUID: SubcategoryLabel]()) { result, subcategory in
            result[subcategory.id] = SubcategoryLabel(name: subcategory.name, emoji: subcategory.emoji)
        }
        return YearRecap(
            year: year,
            transactions: transactions,
            rollups: rollups,
            current: MonthKey(containing: now, timeZone: timeZone),
            subcategories: labels,
            timeZone: timeZone
        )
    }
}
