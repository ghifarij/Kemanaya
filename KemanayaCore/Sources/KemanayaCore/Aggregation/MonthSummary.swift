import Foundation

/// One subcategory's total for a period.
public struct SubcategoryTotal: Hashable, Sendable {
    public let subcategoryID: UUID
    public let kind: TransactionKind
    public let group: ExpenseGroup?
    /// Rupiah (D-016).
    public let total: Int64
    /// Number of transactions.
    public let count: Int

    public init(subcategoryID: UUID, kind: TransactionKind, group: ExpenseGroup?, total: Int64, count: Int) {
        self.subcategoryID = subcategoryID
        self.kind = kind
        self.group = group
        self.total = total
        self.count = count
    }
}

/// Totals for one month: per group, income, and per subcategory (D-014). Sisa and the savings rate
/// were removed with D-070; Analisis shows spending against income as two plain totals (``IncomeLine``).
///
/// Sums clamp at `Int64`'s limit (about 9.2 quintillion rupiah) instead of trapping. Every amount is at
/// most ``AmountEntry/maximum`` (about 10¹², enforced by the keypad and by a restore's validation), so
/// even 13 months of maximum-size entries are millions of entries away from clamping.
public struct MonthSummary: Equatable, Sendable {
    /// Spent on Kebutuhan.
    public let kebutuhan: Int64
    /// Spent on Keinginan.
    public let keinginan: Int64
    /// Pemasukan.
    public let income: Int64
    /// Every subcategory with at least one transaction, **income and expense mixed**, largest total first
    /// (ties: more transactions first, then by id so the order is stable). See ``expenseSubcategories``.
    public let subcategories: [SubcategoryTotal]

    /// Builds the summary from any transactions; pass only the month's (``Ledger`` fetches them by date range).
    /// An expense without a group can't exist in valid data (D-003); one is skipped everywhere,
    /// so group totals and per-subcategory totals always agree.
    public init(_ transactions: some Sequence<TransactionSnapshot>) {
        self.init(transactions, rollups: EmptyCollection<RollupSnapshot>())
    }

    /// Builds the summary from raw transactions **and** monthly rollups (D-017): a rollup counts as its
    /// subcategory's total and count. Pass only the period's; ``MonthTotals`` picks them per month (D-055).
    /// The summary has no month of its own, so the yearly recap sums a whole year with it (D-059).
    public init(_ transactions: some Sequence<TransactionSnapshot>, rollups: some Sequence<RollupSnapshot>) {
        var kebutuhan: Int64 = 0
        var keinginan: Int64 = 0
        var income: Int64 = 0
        var bySubcategory: [UUID: (kind: TransactionKind, group: ExpenseGroup?, total: Int64, count: Int)] = [:]

        func add(_ amount: Int64, count: Int, kind: TransactionKind, group: ExpenseGroup?, subcategoryID id: UUID) {
            switch (kind, group) {
            case (.income, _): income = income.saturatingAdding(amount)
            case (.expense, .kebutuhan): kebutuhan = kebutuhan.saturatingAdding(amount)
            case (.expense, .keinginan): keinginan = keinginan.saturatingAdding(amount)
            case (.expense, nil): return
            }
            var entry = bySubcategory[id, default: (kind, group, 0, 0)]
            entry.total = entry.total.saturatingAdding(amount)
            entry.count += count
            bySubcategory[id] = entry
        }

        for transaction in transactions {
            add(transaction.amount, count: 1, kind: transaction.kind, group: transaction.group, subcategoryID: transaction.subcategoryID)
        }
        for rollup in rollups {
            add(rollup.total, count: rollup.count, kind: rollup.kind, group: rollup.group, subcategoryID: rollup.subcategoryID)
        }

        self.kebutuhan = kebutuhan
        self.keinginan = keinginan
        self.income = income
        self.subcategories = bySubcategory
            .map { SubcategoryTotal(subcategoryID: $0.key, kind: $0.value.kind, group: $0.value.group, total: $0.value.total, count: $0.value.count) }
            .sorted {
                if $0.total != $1.total { return $0.total > $1.total }
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.subcategoryID.uuidString < $1.subcategoryID.uuidString
            }
    }

    /// ``subcategories`` without income, same order. What Breakdown ranks (D-014).
    public var expenseSubcategories: [SubcategoryTotal] {
        subcategories.filter { $0.kind == .expense }
    }

    /// Kebutuhan + Keinginan.
    public var expenses: Int64 { kebutuhan.saturatingAdding(keinginan) }

    /// Spent on `group`.
    public func spent(on group: ExpenseGroup) -> Int64 {
        switch group {
        case .kebutuhan: kebutuhan
        case .keinginan: keinginan
        }
    }

    /// The month's total for one subcategory; 0 when it has no transactions.
    public func total(for subcategoryID: UUID) -> Int64 {
        subcategories.first { $0.subcategoryID == subcategoryID }?.total ?? 0
    }

    /// The month's number of transactions in one subcategory, a rollup's count included; 0 when it has none.
    public func count(for subcategoryID: UUID) -> Int {
        subcategories.first { $0.subcategoryID == subcategoryID }?.count ?? 0
    }

    /// Progress against a group's budget (D-010). Nil when `budget` is nil (no budget set).
    public func budgetProgress(for group: ExpenseGroup, budget: Int64?) -> BudgetProgress? {
        budget.flatMap { BudgetProgress(spent: spent(on: group), budget: $0) }
    }

    /// Progress against one subcategory's budget (D-041). Nil when `budget` is nil.
    /// A budgeted subcategory with no spending yet gets progress with `spent == 0`.
    ///
    /// Doesn't check the kind: only expense subcategories can hold a budget
    /// (``Subcategory/setMonthlyBudget(_:)`` throws for income, and ``Ledger/subcategoryBudgets()``
    /// returns expense budgets only), so take budgets from there.
    public func budgetProgress(forSubcategory subcategoryID: UUID, budget: Int64?) -> BudgetProgress? {
        budget.flatMap { BudgetProgress(spent: total(for: subcategoryID), budget: $0) }
    }

    /// Progress for every budgeted subcategory in `budgets` (id → monthly budget, from
    /// ``Ledger/subcategoryBudgets()``).
    public func subcategoryBudgetProgress(_ budgets: [UUID: Int64]) -> [UUID: BudgetProgress] {
        budgets.reduce(into: [:]) { result, entry in
            result[entry.key] = budgetProgress(forSubcategory: entry.key, budget: entry.value)
        }
    }
}
