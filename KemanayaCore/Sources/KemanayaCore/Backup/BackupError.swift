import Foundation

/// Why a backup file was refused (D-060). Every case is raised before the store changes, so a refused
/// file leaves the data as it was.
public enum BackupError: Error, Equatable, Sendable {
    /// Not JSON, not a Kemanaya backup, or a field can't be decoded (e.g. a damaged date or unknown kind).
    case unreadable
    /// Written by a newer app (`formatVersion` above ``BackupDocument/currentFormatVersion``). Update the app first.
    case newerFormat(Int)
    /// Two subcategories, or two transactions, share this id.
    case duplicateID(UUID)
    /// Two rollups for the same month and subcategory.
    case duplicateRollup(monthKey: Int, subcategoryID: UUID)
    /// A subcategory with an invalid group for its kind, a name that isn't one trimmed word of 1…10
    /// characters (D-007), not exactly one emoji, an invalid budget, or a pin that is negative or on a
    /// hidden subcategory (D-049).
    case invalidSubcategory(UUID)
    /// This subcategory's name matches an earlier one's, ignoring case, diacritics and width (D-062).
    case duplicateName(UUID)
    /// No visible subcategory of this kind and group (D-062), so the add sheet would have no tile there.
    case noVisibleSubcategory(kind: TransactionKind, group: ExpenseGroup?)
    /// Two pinned subcategories share a pin order, or more than ``SubcategoryRules/maximumPins`` are pinned.
    case invalidPins
    /// A transaction with an amount not between 1 and ``AmountEntry/maximum``, an invalid group for its kind,
    /// or a kind or group that differs from its subcategory's.
    case invalidTransaction(UUID)
    /// A rollup with an invalid month, a count or total that isn't positive, a total above
    /// ``AmountEntry/maximum`` × count, or an invalid group for its kind.
    case invalidRollup(monthKey: Int, subcategoryID: UUID)
    /// A group budget that is zero or negative.
    case invalidSettings

    /// True when the file is from a newer app, which needs its own message ("update the app").
    public var isNewerFormat: Bool {
        if case .newerFormat = self { true } else { false }
    }
}
