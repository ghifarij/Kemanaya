import Foundation
import KemanayaCore
import Testing

struct MonthKeyTests {
    @Test func monthOfADate() {
        #expect(MonthKey(containing: Fixtures.date(2026, 11, 17), timeZone: Fixtures.jakarta) == MonthKey(year: 2026, month: 11))
    }

    @Test func nextAndPreviousCrossYearBoundaries() {
        #expect(MonthKey(year: 2026, month: 12).next == MonthKey(year: 2027, month: 1))
        #expect(MonthKey(year: 2027, month: 1).previous == MonthKey(year: 2026, month: 12))
        #expect(MonthKey(year: 2026, month: 6).next == MonthKey(year: 2026, month: 7))
    }

    @Test func addingManyMonths() {
        let november = MonthKey(year: 2026, month: 11)
        #expect(november.adding(months: -12) == MonthKey(year: 2025, month: 11))
        #expect(november.adding(months: -11) == MonthKey(year: 2025, month: 12))
        #expect(november.adding(months: -23) == MonthKey(year: 2024, month: 12))
        #expect(november.adding(months: 14) == MonthKey(year: 2028, month: 1))
        #expect(november.adding(months: 0) == november)
    }

    @Test func rangeIsHalfOpenFromStartOfMonthToStartOfNextMonth() {
        let range = MonthKey(year: 2026, month: 12).dateRange(in: Fixtures.jakarta)
        #expect(range.lowerBound == Fixtures.date(2026, 12, 1, 0))
        #expect(range.upperBound == Fixtures.date(2027, 1, 1, 0))
        #expect(range.contains(Fixtures.date(2026, 12, 31, 23, 59, 59)))
        #expect(!range.contains(Fixtures.date(2027, 1, 1, 0)))
        #expect(!range.contains(Fixtures.date(2026, 11, 30, 23, 59, 59)))
    }

    @Test func februaryInALeapYear() {
        let range = MonthKey(year: 2028, month: 2).dateRange(in: Fixtures.jakarta)
        #expect(range.upperBound == Fixtures.date(2028, 3, 1, 0))
        #expect(range.contains(Fixtures.date(2028, 2, 29, 23)))
    }

    /// 1 Dec 2026 01:00 in Jakarta is still 30 Nov in Los Angeles: the injected time zone decides the bucket.
    @Test func bucketingFollowsTheTimeZone() {
        let instant = Fixtures.date(2026, 12, 1, 1, in: Fixtures.jakarta)
        #expect(MonthKey(containing: instant, timeZone: Fixtures.jakarta) == MonthKey(year: 2026, month: 12))
        #expect(MonthKey(containing: instant, timeZone: Fixtures.losAngeles) == MonthKey(year: 2026, month: 11))

        let losAngelesRange = MonthKey(year: 2026, month: 11).dateRange(in: Fixtures.losAngeles)
        #expect(losAngelesRange.lowerBound == Fixtures.date(2026, 11, 1, 0, in: Fixtures.losAngeles))
        #expect(losAngelesRange.contains(instant))
    }

    /// Los Angeles leaves daylight saving time on 1 Nov 2026, so November there is 30 days and 1 hour long.
    @Test func rangeSpansADaylightSavingChange() {
        let range = MonthKey(year: 2026, month: 11).dateRange(in: Fixtures.losAngeles)
        #expect(range.upperBound.timeIntervalSince(range.lowerBound) == (30 * 24 + 1) * 3600)
    }

    /// A device on the Buddhist calendar (year 2569) still buckets into Gregorian 2026 (no `Calendar` to misuse).
    @Test func alwaysGregorian() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = Fixtures.jakarta
        let date = buddhist.date(from: DateComponents(year: 2569, month: 11, day: 17))!
        #expect(MonthKey(containing: date, timeZone: Fixtures.jakarta) == MonthKey(year: 2026, month: 11))
    }

    @Test func rawValueRoundTrips() {
        let key = MonthKey(year: 2026, month: 11)
        #expect(key.rawValue == 202611)
        #expect(MonthKey(rawValue: 202611) == key)
        #expect(MonthKey(rawValue: 202613) == nil)
        #expect(MonthKey(rawValue: 202600) == nil)
    }

    @Test func ordersChronologically() {
        let months = [MonthKey(year: 2027, month: 1), MonthKey(year: 2026, month: 12), MonthKey(year: 2026, month: 2)]
        #expect(months.sorted() == [MonthKey(year: 2026, month: 2), MonthKey(year: 2026, month: 12), MonthKey(year: 2027, month: 1)])
        #expect(MonthKey(year: 2026, month: 11).description == "2026-11")
    }
}

struct RetentionWindowTests {
    /// The D-017 example: in Nov 2026 the whole of Nov 2025 is visible.
    @Test func windowStartsTwelveMonthsBeforeThisMonth() {
        let now = Fixtures.date(2026, 11, 17)
        #expect(RetentionWindow.rawWindowStart(now: now, timeZone: Fixtures.jakarta) == Fixtures.date(2025, 11, 1, 0))
        #expect(RetentionWindow.firstRawMonth(now: now, timeZone: Fixtures.jakarta) == MonthKey(year: 2025, month: 11))
    }

    /// On 1 Dec 2026 Nov 2025 drops out of the window.
    @Test func windowMovesOnTheFirstOfTheMonth() {
        let lastMomentOfNovember = Fixtures.date(2026, 11, 30, 23, 59, 59)
        let firstMomentOfDecember = Fixtures.date(2026, 12, 1, 0)
        #expect(RetentionWindow.rawWindowStart(now: lastMomentOfNovember, timeZone: Fixtures.jakarta) == Fixtures.date(2025, 11, 1, 0))
        #expect(RetentionWindow.rawWindowStart(now: firstMomentOfDecember, timeZone: Fixtures.jakarta) == Fixtures.date(2025, 12, 1, 0))
    }

    @Test func windowCrossesTheYearBoundary() {
        let now = Fixtures.date(2027, 1, 5)
        #expect(RetentionWindow.rawWindowStart(now: now, timeZone: Fixtures.jakarta) == Fixtures.date(2026, 1, 1, 0))
    }

    @Test func windowUsesTheTimeZone() {
        // 1 Dec 2026 03:00 Jakarta = 30 Nov 2026 12:00 Los Angeles.
        let now = Fixtures.date(2026, 12, 1, 3, in: Fixtures.jakarta)
        #expect(RetentionWindow.rawWindowStart(now: now, timeZone: Fixtures.jakarta) == Fixtures.date(2025, 12, 1, 0, in: Fixtures.jakarta))
        #expect(RetentionWindow.rawWindowStart(now: now, timeZone: Fixtures.losAngeles) == Fixtures.date(2025, 11, 1, 0, in: Fixtures.losAngeles))
    }
}
