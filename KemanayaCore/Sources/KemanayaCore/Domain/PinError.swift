/// Why a subcategory couldn't be pinned on Home. Checked before anything changes.
public enum PinError: Error, Equatable, Sendable {
    /// The subcategory's Home section already holds ``PinSection/limit`` pins (D-068).
    case limitReached(PinSection)
    /// Hidden subcategories don't appear on Home (D-006), so they can't be pinned.
    case subcategoryHidden
}
