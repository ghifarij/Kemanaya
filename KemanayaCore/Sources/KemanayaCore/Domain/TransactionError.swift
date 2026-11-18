/// Why a transaction couldn't be added or updated. Checked before anything changes, so a
/// rejected write leaves the store as it was.
public enum TransactionError: Error, Equatable, Sendable {
    /// Amounts are positive whole rupiah; the kind carries the direction (D-016).
    case amountNotPositive
    /// New entries can't go into a hidden subcategory (D-006). A transaction already in one may stay there.
    case subcategoryHidden
    /// Entries may be dated up to the end of the current month, never in a later month (D-044).
    case dateAfterCurrentMonth
    /// New entries can't be dated before the D-017 raw window (this month and the 12 before it).
    /// An edit may keep a transaction's existing older date (D-044).
    case dateBeforeRawWindow
}
