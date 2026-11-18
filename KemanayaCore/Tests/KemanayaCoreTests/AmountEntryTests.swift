import KemanayaCore
import Testing

struct AmountEntryTests {
    /// Presses every key in order and returns the entry.
    private func typed(_ keys: KeypadInput..., startingAt amount: Int64 = 0) -> AmountEntry {
        var entry = AmountEntry(amount: amount)
        for key in keys { entry.press(key) }
        return entry
    }

    /// Presses `key` on a copy of `entry`: the result and the amount after it.
    /// (`#expect` can't call a mutating method itself.)
    private func pressing(_ key: KeypadInput, on entry: AmountEntry) -> (result: AmountEntry.KeyResult, amount: Int64) {
        var copy = entry
        let result = copy.press(key)
        return (result, copy.amount)
    }

    @Test func startsEmpty() {
        let entry = AmountEntry()
        #expect(entry.amount == 0)
        #expect(entry.isEmpty)
    }

    @Test func digitsAppendLikeACalculator() {
        #expect(typed(.digit(2), .digit(5)).amount == 25)
        #expect(typed(.digit(2), .digit(5), .tripleZero).amount == 25_000)
        #expect(typed(.digit(1), .digit(0), .digit(0)).amount == 100)
        #expect(typed(.digit(1), .digit(2), .digit(7), .digit(5), .digit(0), .digit(0)).amount == 127_500)
        #expect(!typed(.digit(7)).isEmpty)
    }

    @Test func noLeadingZeros() {
        let empty = AmountEntry()
        #expect(pressing(.digit(0), on: empty) == (.ignored, 0))
        #expect(pressing(.tripleZero, on: empty) == (.ignored, 0))
        #expect(pressing(.digit(4), on: empty) == (.accepted, 4))
        #expect(pressing(.digit(0), on: AmountEntry(amount: 4)) == (.accepted, 40))
    }

    @Test func backspaceDropsTheLastDigit() {
        #expect(pressing(.backspace, on: typed(.digit(2), .digit(5), .tripleZero)) == (.accepted, 2_500))
        #expect(pressing(.backspace, on: typed(.digit(9))) == (.accepted, 0))
        #expect(pressing(.backspace, on: AmountEntry()) == (.ignored, 0), "backspace on an empty amount is not a rejection")
    }

    @Test func invalidDigitsAreIgnored() {
        let entry = AmountEntry(amount: 12)
        #expect(pressing(.digit(10), on: entry) == (.ignored, 12))
        #expect(pressing(.digit(-1), on: entry) == (.ignored, 12))
    }

    @Test func clearEmptiesTheAmount() {
        var entry = AmountEntry(amount: 75_000)
        entry.clear()
        #expect(entry.isEmpty)
    }

    // MARK: - The 12-digit cap: keys past it are rejected whole, never clamped.

    @Test func maximumIsTwelveNines() {
        #expect(AmountEntry.maximum == 999_999_999_999)
        #expect(String(AmountEntry.maximum).count == AmountEntry.maximumDigits)
    }

    @Test func aThirteenthDigitIsRejected() {
        #expect(pressing(.digit(3), on: AmountEntry(amount: 123_456_789_012)) == (.rejectedAtCap, 123_456_789_012))
        // Twelve nines are allowed exactly.
        var nines = AmountEntry()
        for _ in 0..<12 { nines.press(.digit(9)) }
        #expect(nines.amount == AmountEntry.maximum)
        #expect(pressing(.digit(9), on: nines) == (.rejectedAtCap, AmountEntry.maximum))
        #expect(pressing(.digit(0), on: nines) == (.rejectedAtCap, AmountEntry.maximum))
        // Backspace still works at the cap.
        #expect(pressing(.backspace, on: nines) == (.accepted, 99_999_999_999))
    }

    @Test func tripleZeroThatWouldPassTheCapIsRejectedWhole() {
        // 10 digits + 000 = 13 digits: rejected, not trimmed to two zeros.
        #expect(pressing(.tripleZero, on: AmountEntry(amount: 1_234_567_890)) == (.rejectedAtCap, 1_234_567_890))
        // 9 digits + 000 = 12 digits: fits.
        #expect(pressing(.tripleZero, on: AmountEntry(amount: 123_456_789)) == (.accepted, 123_456_789_000))
    }

    @Test func initialAmountIsClampedIntoRange() {
        #expect(AmountEntry(amount: -5).amount == 0)
        #expect(AmountEntry(amount: .max).amount == AmountEntry.maximum)
        #expect(AmountEntry(amount: 45_000).amount == 45_000)
    }
}
