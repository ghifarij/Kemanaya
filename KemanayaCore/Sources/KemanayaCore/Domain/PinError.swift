/// Why a subcategory couldn't be pinned on Home. Checked before anything changes. A section has no pin
/// limit (D-079), so the only refusal is a hidden subcategory.
public enum PinError: Error, Equatable, Sendable {
    /// Hidden subcategories don't appear on Home (D-006), so they can't be pinned.
    case subcategoryHidden
}
