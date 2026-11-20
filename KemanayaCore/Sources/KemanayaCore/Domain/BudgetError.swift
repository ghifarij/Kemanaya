/// Why a budget couldn't be set. Checked before anything changes.
public enum BudgetError: Error, Equatable, Sendable {
    /// Only expense subcategories have budgets (D-041).
    case incomeHasNoBudget
    /// More than the keypad can type, ``AmountEntry/maximum`` (D-062). A restore refuses it too (D-060).
    case overMaximum
}
