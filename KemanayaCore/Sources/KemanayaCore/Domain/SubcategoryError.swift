/// Why a typed subcategory name can't be saved (D-007, D-062). The editor shows the reason live.
public enum SubcategoryNameProblem: Equatable, Sendable {
    /// Nothing but spaces.
    case empty
    /// More than one word (D-007).
    case notOneWord
    /// Longer than ``SubcategoryRules/maximumNameLength`` characters (D-007).
    case tooLong
    /// Another subcategory, of either kind and hidden or not, already has this name, ignoring case and
    /// diacritics (D-062).
    case taken
}

/// Why a subcategory write was refused. Checked before anything changes, so a refused write leaves the
/// store as it was. Budget problems are ``BudgetError``s.
public enum SubcategoryError: Error, Equatable, Sendable {
    case invalidName(SubcategoryNameProblem)
    /// Not exactly one emoji (``SubcategoryRules/isValidEmoji(_:)``, D-007).
    case invalidEmoji
    /// An expense without a group or income with one (D-003, D-005).
    case invalidPlacement
    /// The last visible subcategory of its kind (for expenses, of its group) can't be hidden or deleted,
    /// so the add sheet always has a tile there (D-062).
    case lastVisibleInSection
}

/// What removing a subcategory does (D-006, D-062), so the confirmation can say it before it happens.
public enum SubcategoryRemoval: Equatable, Sendable {
    /// No transactions and no rollups refer to it: it is deleted.
    case delete
    /// It has history: it is hidden instead, and its history stays (D-006). Hiding unpins it (D-049).
    case hide
    /// It is the last visible one of its kind or group (``SubcategoryError/lastVisibleInSection``).
    case notAllowed
}
