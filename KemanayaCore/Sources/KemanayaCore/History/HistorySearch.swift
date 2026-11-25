import Foundation

/// History's search (D-053, D-057): one query matched against a transaction's subcategory name (shown and
/// stored, D-076), its note and its amount, narrowing on every keystroke.
///
/// - Text matches when the name or the note contains the query, ignoring case, diacritics and width
///   ("cafe" finds "Café", "KOPI" finds "Kopi").
/// - A query made of digits matches amounts whose rupiah digits **start with** those digits, ignoring an
///   "Rp" prefix and the "." / "," separators and spaces: "18" finds Rp18.000, Rp180.000 and Rp1.800,
///   and "18.000" narrows to Rp18.000, Rp18.000.000, …. The same query still matches as text too, so a
///   note like "Kamar 18" is found by "18".
///
/// Deterministic: it never reads the device locale, like ``RupiahFormatter``.
public struct HistorySearch: Equatable, Sendable {
    /// The query folded for comparison; empty when the query is blank.
    public let folded: String
    /// The ASCII digits of a digits-only query, which amounts are matched against as a prefix, or nil
    /// when the query isn't one. Kept as text, so any length is safe: nothing is parsed into a number.
    public let amountPrefix: String?

    public init(_ query: String) {
        let folded = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        self.folded = folded
        self.amountPrefix = Self.amountDigits(in: folded)
    }

    /// A blank query: History shows every transaction.
    public var isEmpty: Bool { folded.isEmpty }

    /// Whether a transaction with this subcategory `name`, `note` and `amount` matches. A blank query
    /// matches everything.
    public func matches(name: String, note: String?, amount: Int64) -> Bool {
        matches(names: CollectionOfOne(name), note: note, amount: amount)
    }

    /// Whether a transaction matches when its subcategory goes by any of `names`: a seeded subcategory
    /// matches both the name shown in the app language and its stored Indonesian name (D-076), so
    /// "Food" and "Makan" both find it. A blank query matches everything.
    public func matches(names: some Sequence<String>, note: String?, amount: Int64) -> Bool {
        if isEmpty { return true }
        if let amountPrefix, String(amount).hasPrefix(amountPrefix) { return true }
        if names.contains(where: { Self.fold($0).contains(folded) }) { return true }
        if let note, Self.fold(note).contains(folded) { return true }
        return false
    }

    /// Predictive suggestions while typing (D-057): up to `limit` of `names` that contain the query, folded
    /// the same way as ``matches(name:note:amount:)``. Names that start with the query come first, then
    /// names that only contain it, each alphabetical by folded name. Names that fold to the same text
    /// appear once. A name equal to the query is left out: it is already typed, so choosing it would do
    /// nothing, and the results show again once a suggestion is chosen. Empty for a blank query.
    public func suggestions(from names: some Sequence<String>, limit: Int = 5) -> [String] {
        guard !isEmpty, limit > 0 else { return [] }
        var seen: Set<String> = []
        var candidates: [(name: String, folded: String, isPrefix: Bool)] = []
        for name in names {
            let foldedName = Self.fold(name)
            guard foldedName != folded, foldedName.contains(folded), seen.insert(foldedName).inserted else { continue }
            candidates.append((name, foldedName, foldedName.hasPrefix(folded)))
        }
        return candidates
            .sorted { lhs, rhs in
                if lhs.isPrefix != rhs.isPrefix { return lhs.isPrefix }
                return lhs.folded < rhs.folded
            }
            .prefix(limit)
            .map(\.name)
    }

    /// Case-, diacritic- and width-insensitive form of `text`.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// The digits in an already folded query: an optional "rp" prefix, then ASCII digits with any "." / ","
    /// separators and spaces. Nil when anything else is in it or there are no digits.
    static func amountDigits(in folded: String) -> String? {
        var text = Substring(folded)
        if text.hasPrefix("rp") { text = text.dropFirst(2) }
        let separators: Set<Character> = [".", ",", " ", "\u{00A0}"]
        let digits = text.filter { !separators.contains($0) }
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isWholeNumber }) else { return nil }
        return digits
    }
}
