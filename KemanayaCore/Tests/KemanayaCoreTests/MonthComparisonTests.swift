import KemanayaCore
import Testing

struct MonthComparisonTests {
    @Test func direction() {
        #expect(MonthComparison(current: 2, previous: 1).direction == .up)
        #expect(MonthComparison(current: 1, previous: 2).direction == .down)
        #expect(MonthComparison(current: 1, previous: 1).direction == .same)
        #expect(MonthComparison(current: 0, previous: 0).direction == .same)
    }

    @Test func fractionsAreRelativeToTheLargerMonth() {
        let comparison = MonthComparison(current: 50, previous: 200)
        #expect(comparison.currentFraction == 0.25)
        #expect(comparison.previousFraction == 1)
    }

    @Test func bothZeroGivesEmptyBars() {
        let comparison = MonthComparison(current: 0, previous: 0)
        #expect(comparison.currentFraction == 0)
        #expect(comparison.previousFraction == 0)
    }

    @Test func extremesDoNotOverflow() {
        let comparison = MonthComparison(current: .max, previous: 1)
        #expect(comparison.currentFraction == 1)
        #expect(comparison.previousFraction > 0)
    }
}
