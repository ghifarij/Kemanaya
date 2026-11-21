import Foundation

/// The one line between Rincian and Tren on Analisis (D-070): the month's spending, with its income as
/// context. "Pengeluaran Rp4,3jt dari pemasukan Rp8,5jt", or "Pengeluaran Rp4,3jt · belum ada pemasukan"
/// with no income. It always counts **all** expenses, whatever the group filter: income has no group.
///
/// A neutral pair of facts (D-022): no difference, rate or verdict (sisa and the savings rate are gone, D-070).
public enum IncomeLine: Equatable, Sendable {
    /// Some income this month: spending against it (spending may be 0).
    case spentOfIncome(spent: Int64, income: Int64)
    /// Spending, but no income logged yet.
    case noIncome(spent: Int64)

    /// Nil when the month has neither spending nor income: the page's empty state already says so.
    public init?(_ summary: MonthSummary) {
        let spent = summary.expenses
        let income = summary.income
        if income > 0 {
            self = .spentOfIncome(spent: spent, income: income)
        } else if spent > 0 {
            self = .noIncome(spent: spent)
        } else {
            return nil
        }
    }
}
