import Foundation
import KemanayaCore
import Testing

/// The Analisis month stepper's bounds (D-017, D-051).
struct AnalysisMonthRangeTests {
    private let november = MonthKey(year: 2026, month: 11)

    @Test func spansThirteenMonthsEndingAtTheCurrentMonth() {
        let range = AnalysisMonthRange(current: november)
        #expect(range.latest == november)
        #expect(range.earliest == MonthKey(year: 2025, month: 11))
        #expect(november.adding(months: -12) == range.earliest, "13 months, both ends included")
    }

    /// The stepper's oldest month is the raw window's first month (D-017), in the injected zone.
    @Test func matchesTheRawWindowInTheGivenTimeZone() {
        // 1 Dec 2026 00:30 in Jakarta is still 30 Nov in Los Angeles.
        let instant = Fixtures.date(2026, 12, 1, 0, 30)
        let jakarta = AnalysisMonthRange(current: MonthKey(containing: instant, timeZone: Fixtures.jakarta))
        #expect(jakarta.latest == MonthKey(year: 2026, month: 12))
        #expect(jakarta.earliest == RetentionWindow.firstRawMonth(now: instant, timeZone: Fixtures.jakarta))
        let losAngeles = AnalysisMonthRange(current: MonthKey(containing: instant, timeZone: Fixtures.losAngeles))
        #expect(losAngeles.latest == november)
        #expect(losAngeles.earliest == MonthKey(year: 2025, month: 11))
    }

    @Test func stepsStopAtBothEnds() {
        let range = AnalysisMonthRange(current: november)
        #expect(range.month(after: november) == nil, "no months after the current one (D-044)")
        #expect(range.month(before: november) == MonthKey(year: 2026, month: 10))
        #expect(range.month(before: range.earliest) == nil, "nothing before the 13-month window")
        #expect(range.month(after: range.earliest) == MonthKey(year: 2025, month: 12))
    }

    @Test func crossesTheYearBoundary() {
        let range = AnalysisMonthRange(current: MonthKey(year: 2027, month: 1))
        #expect(range.earliest == MonthKey(year: 2026, month: 1))
        #expect(range.month(before: MonthKey(year: 2027, month: 1)) == MonthKey(year: 2026, month: 12))
    }

    @Test func clampsMonthsOutsideTheRange() {
        let range = AnalysisMonthRange(current: november)
        #expect(range.clamped(MonthKey(year: 2030, month: 1)) == november)
        #expect(range.clamped(MonthKey(year: 2020, month: 1)) == range.earliest)
        #expect(range.clamped(MonthKey(year: 2026, month: 5)) == MonthKey(year: 2026, month: 5))
        #expect(range.contains(range.earliest) && range.contains(november))
        #expect(!range.contains(november.next) && !range.contains(range.earliest.previous))
        // A stale selection outside the range steps from its clamped month.
        #expect(range.month(before: MonthKey(year: 2030, month: 1)) == MonthKey(year: 2026, month: 10))
    }

    /// When a new month starts, a selection on the old current month follows; others stay unless they fall out.
    @Test func carriesTheSelectionIntoANewMonth() {
        let old = AnalysisMonthRange(current: november)
        let new = AnalysisMonthRange(current: november.next)
        #expect(new.carrying(november, from: old) == november.next, "following 'this month'")
        #expect(new.carrying(MonthKey(year: 2026, month: 6), from: old) == MonthKey(year: 2026, month: 6))
        #expect(new.carrying(old.earliest, from: old) == new.earliest, "the oldest month dropped out of the window")
        #expect(old.carrying(november, from: old) == november, "no change, no move")
    }
}
