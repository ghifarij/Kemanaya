import KemanayaCore
import Testing

struct SplitShareTests {
    @Test func emptySplitHasNoShares() {
        let share = SplitShare(first: 0, second: 0)
        #expect(share.isEmpty)
        #expect(share.firstFraction == 0)
        #expect(share.percentages == (0, 0))
        #expect(share.segmentWidths(totalWidth: 300, gap: 4, minimumWidth: 8) == (0, 0))
    }

    @Test func oneSideZeroTakesEverything() {
        let onlyFirst = SplitShare(first: 50_000, second: 0)
        #expect(onlyFirst.percentages == (100, 0))
        #expect(onlyFirst.segmentWidths(totalWidth: 300, gap: 4, minimumWidth: 8) == (300, 0))

        let onlySecond = SplitShare(first: 0, second: 50_000)
        #expect(onlySecond.percentages == (0, 100))
        #expect(onlySecond.segmentWidths(totalWidth: 300, gap: 4, minimumWidth: 8) == (0, 300))
    }

    @Test func percentagesAddUpTo100() {
        let share = SplitShare(first: 2, second: 1)
        #expect(share.percentages == (67, 33))
    }

    @Test func tinyShareNeverRoundsToZeroOrHundred() {
        let share = SplitShare(first: 1, second: 10_000)
        #expect(share.percentages == (1, 99))
        let flipped = SplitShare(first: 10_000, second: 1)
        #expect(flipped.percentages == (99, 1))
    }

    @Test func tinyShareGetsMinimumWidth() {
        let widths = SplitShare(first: 1, second: 10_000).segmentWidths(totalWidth: 304, gap: 4, minimumWidth: 8)
        #expect(widths.first == 8)
        #expect(widths.second == 292)
    }

    @Test func widthsAreProportionalAndLeaveTheGap() {
        let widths = SplitShare(first: 3, second: 1).segmentWidths(totalWidth: 404, gap: 4, minimumWidth: 8)
        #expect(widths.first == 300)
        #expect(widths.second == 100)
    }

    @Test func hugeAmountsDoNotOverflow() {
        let share = SplitShare(first: .max, second: .max)
        #expect(share.percentages == (50, 50))
    }

    @Test func negativeAmountsCountAsZero() {
        #expect(SplitShare(first: -5, second: 10).percentages == (0, 100))
    }
}
