/// One key of the rupiah keypad (D-013): the input ``AmountEntry`` reduces and the app's `KeypadKey` draws.
public enum KeypadInput: Hashable, Sendable {
    /// A single digit, `0...9`. Anything else is ignored by ``AmountEntry``.
    case digit(Int)
    /// `000`, the fastest way to type rupiah amounts.
    case tripleZero
    /// Drops the last digit.
    case backspace

    /// The keypad's rows, top to bottom: `1 2 3 / 4 5 6 / 7 8 9 / 000 0 ⌫`.
    public static let rows: [[KeypadInput]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.tripleZero, .digit(0), .backspace],
    ]
}
