/// Rules every subcategory follows, shared by the seed, the editor (Phase 10) and pin management (Phase 5).
public enum SubcategoryRules {
    /// Longest allowed name, in characters (D-007).
    public static let maximumNameLength = 10

    /// Most subcategories that can be pinned on Home at once (D-012).
    public static let maximumPins = 9

    /// True when `name` is one word of 1…10 characters (D-007).
    public static func isValidName(_ name: String) -> Bool {
        !name.isEmpty
            && name.count <= maximumNameLength
            && !name.contains(where: \.isWhitespace)
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
