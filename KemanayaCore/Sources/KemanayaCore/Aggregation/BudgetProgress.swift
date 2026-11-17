/// How much of a monthly group budget is used (D-010).
///
/// Neutral numbers only; copy and color decide tone, and only staying under budget may be celebrated (D-022).
public struct BudgetProgress: Equatable, Sendable {
    /// Rupiah spent this month.
    public let spent: Int64
    /// The budget, always > 0.
    public let budget: Int64

    /// Nil when `budget` is zero or negative: that means "no budget", not "everything is over budget".
    public init?(spent: Int64, budget: Int64) {
        guard budget > 0 else { return nil }
        self.spent = max(spent, 0)
        self.budget = budget
    }

    /// Budget − spent. Negative when over budget.
    public var remaining: Int64 { budget - spent }

    /// Spent ÷ budget, unclamped: `1.25` means 25 % over.
    public var fraction: Double { Double(spent) / Double(budget) }

    /// ``fraction`` clamped to `0...1`, for drawing a bar.
    public var clampedFraction: Double { min(fraction, 1) }

    /// True once spending passes the budget. Spending exactly the budget is not over.
    public var isOverBudget: Bool { spent > budget }
}
