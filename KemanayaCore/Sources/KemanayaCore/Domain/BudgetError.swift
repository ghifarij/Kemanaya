/// Why a budget couldn't be set.
public enum BudgetError: Error, Equatable, Sendable {
    /// Only expense subcategories have budgets (D-041).
    case incomeHasNoBudget
}
