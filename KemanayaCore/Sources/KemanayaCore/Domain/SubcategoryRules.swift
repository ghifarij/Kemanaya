import Foundation

/// Rules every subcategory follows, shared by the seed, the editor (Phase 10) and pin management (Phase 5).
public enum SubcategoryRules {
    /// Longest allowed name, in characters (D-007).
    public static let maximumNameLength = 10

    /// Most subcategories that can be pinned in `section` at once (D-068): see ``PinSection/limit``.
    public static func maximumPins(in section: PinSection) -> Int {
        section.limit
    }

    /// True when `name` is one word of 1…10 characters (D-007).
    public static func isValidName(_ name: String) -> Bool {
        !name.isEmpty
            && name.count <= maximumNameLength
            && !name.contains(where: \.isWhitespace)
    }

    /// The name as stored: surrounding spaces and newlines removed.
    public static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The key two names are compared by: ignoring case and diacritics, so "Kopi", "kopi" and "Kopí"
    /// are the same name (D-062). Locale-independent, so the result never changes with the device language.
    public static func comparisonKey(_ name: String) -> String {
        normalizedName(name).folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Why `name` can't be saved, or nil when it can. `name` is trimmed first (``normalizedName(_:)``).
    ///
    /// - Parameter takenNames: the names of every *other* subcategory, both kinds, hidden ones included
    ///   (leave out the one being renamed, so changing only its case is allowed).
    public static func nameProblem(_ name: String, takenNames: some Sequence<String>) -> SubcategoryNameProblem? {
        let trimmed = normalizedName(name)
        if trimmed.isEmpty { return .empty }
        if trimmed.contains(where: \.isWhitespace) { return .notOneWord }
        if trimmed.count > maximumNameLength { return .tooLong }
        let key = comparisonKey(trimmed)
        if takenNames.contains(where: { comparisonKey($0) == key }) { return .taken }
        return nil
    }

    /// True when `emoji` is exactly one emoji shown as emoji, e.g. `☕`, `🅿️` or `1️⃣` (D-007).
    ///
    /// Accepted: a character that starts with a default-emoji scalar (`☕`, `🤲`, flags, skin tones),
    /// or one with the emoji selector U+FE0F (`🅿️`, `↩️`, keycap `1️⃣`). Rejected: plain text (`a`, `1`, `#`),
    /// text-style selections (U+FE0E) and bare keycaps without U+FE0F (`1⃣`).
    public static func isValidEmoji(_ emoji: String) -> Bool {
        guard emoji.count == 1, let first = emoji.unicodeScalars.first else { return false }
        let scalars = emoji.unicodeScalars
        if scalars.contains("\u{FE0E}") { return false }
        if first.properties.isEmojiPresentation { return true }
        return first.properties.isEmoji && scalars.contains("\u{FE0F}")
    }

    /// True when a subcategory of `kind` has a valid group: expenses need one, income has none (D-003, D-005).
    public static func isValidPlacement(kind: TransactionKind, group: ExpenseGroup?) -> Bool {
        (kind == .expense) == (group != nil)
    }
}
