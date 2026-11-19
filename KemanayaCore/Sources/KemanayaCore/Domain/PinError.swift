/// Why a subcategory couldn't be pinned on Home. Checked before anything changes.
public enum PinError: Error, Equatable, Sendable {
    /// Home already shows ``SubcategoryRules/maximumPins`` cards (D-012).
    case limitReached
    /// Hidden subcategories don't appear on Home (D-006), so they can't be pinned.
    case subcategoryHidden
}
