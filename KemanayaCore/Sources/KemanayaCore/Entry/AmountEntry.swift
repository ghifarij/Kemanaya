/// The amount being typed in the add sheet (D-013, D-044): whole rupiah (D-016), built from keypad keys.
/// A pure value, so every rule is unit-tested and the view only draws it.
///
/// Rules:
/// - Digits append like a calculator; there are no leading zeros (`0` or `000` on an empty amount does nothing).
/// - Backspace drops the last digit.
/// - The amount never exceeds ``maximum`` (12 digits). A key that would pass it is **rejected whole**,
///   never clamped or trimmed: a 13th digit or a `000` that doesn't fit leaves the amount as it was.
///   Clamping would silently store a number the user never typed.
///
/// ``press(_:)`` reports what happened, so the sheet can play a warning haptic on ``KeyResult/rejectedAtCap``.
public struct AmountEntry: Hashable, Sendable {
    /// What a key press did.
    public enum KeyResult: Hashable, Sendable {
        /// The amount changed.
        case accepted
        /// Nothing to do: a leading zero, backspace on an empty amount, or a digit outside `0...9`.
        case ignored
        /// The key would have pushed the amount past ``AmountEntry/maximum``, so it was refused.
        case rejectedAtCap
    }

    /// Most digits an amount can have.
    public static let maximumDigits = 12
    /// `Rp999.999.999.999`, the largest amount the keypad produces.
    public static let maximum: Int64 = 999_999_999_999

    /// Whole rupiah, `0...maximum`. 0 means nothing typed yet.
    public private(set) var amount: Int64

    /// - Parameter amount: a starting amount, e.g. the transaction being edited. Clamped into `0...maximum`.
    public init(amount: Int64 = 0) {
        self.amount = min(max(amount, 0), Self.maximum)
    }

    /// True when nothing has been typed, so there is nothing to save.
    public var isEmpty: Bool { amount == 0 }

    /// Applies one keypad key.
    @discardableResult
    public mutating func press(_ key: KeypadInput) -> KeyResult {
        switch key {
        case .digit(let digit):
            guard (0...9).contains(digit) else { return .ignored }
            // amount ≤ maximum, so this can't overflow Int64.
            return replace(with: amount * 10 + Int64(digit))
        case .tripleZero:
            return replace(with: amount * 1_000)
        case .backspace:
            return replace(with: amount / 10)
        }
    }

    /// Back to empty.
    public mutating func clear() {
        amount = 0
    }

    /// Takes `candidate` unless it passes the cap or changes nothing.
    private mutating func replace(with candidate: Int64) -> KeyResult {
        guard candidate <= Self.maximum else { return .rejectedAtCap }
        guard candidate != amount else { return .ignored }
        amount = candidate
        return .accepted
    }
}
