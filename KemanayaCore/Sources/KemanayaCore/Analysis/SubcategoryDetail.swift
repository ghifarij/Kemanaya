import Foundation

/// What a subcategory's detail screen shows for a month (D-051): its total, budget progress when a
/// budget is set (D-041), the comparison with last month, and the month's transactions.
/// Neutral numbers only; the screen states differences without praise or alarm (D-022).
public struct SubcategoryDetail: Equatable, Sendable {
    public let subcategoryID: UUID
    /// This month's total against last month's.
    public let comparison: MonthComparison
    /// Progress against the subcategory's monthly budget; nil without one (and always for income).
    public let budget: BudgetProgress?
    /// This month's transactions in the subcategory, in the order given. Only counted here: the detail
    /// screen lists the transactions from its own `@Query`, which sets their order.
    public let transactions: [TransactionSnapshot]

    /// - Parameters:
    ///   - current: the month's transactions; others are filtered out by `subcategoryID`.
    ///   - previous: last month's transactions, filtered the same way.
    ///   - monthlyBudget: ``Subcategory/monthlyBudget``; nil, zero or negative means none.
    public init(
        subcategoryID: UUID,
        current: some Sequence<TransactionSnapshot>,
        previous: some Sequence<TransactionSnapshot>,
        monthlyBudget: Int64?
    ) {
        let mine = current.filter { $0.subcategoryID == subcategoryID }
        let total = mine.reduce(Int64(0)) { $0 + $1.amount }
        let lastMonth = previous.reduce(Int64(0)) { $1.subcategoryID == subcategoryID ? $0 + $1.amount : $0 }
        self.subcategoryID = subcategoryID
        self.comparison = MonthComparison(current: total, previous: lastMonth)
        self.budget = monthlyBudget.flatMap { BudgetProgress(spent: total, budget: $0) }
        self.transactions = mine
    }

    /// This month's total.
    public var total: Int64 { comparison.current }

    /// Last month's total.
    public var previousTotal: Int64 { comparison.previous }

    /// This month minus last month: positive = more than last month. Neutral, never a verdict.
    public var difference: Int64 { comparison.current - comparison.previous }

    /// Number of transactions this month.
    public var count: Int { transactions.count }

    /// Nothing logged in the subcategory this month.
    public var isEmpty: Bool { transactions.isEmpty }
}
