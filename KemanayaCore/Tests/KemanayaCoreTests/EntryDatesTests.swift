import Foundation
import KemanayaCore
import Testing

/// The dates an entry may have (D-044): from the D-017 raw window start through the end of the current month.
struct EntryDatesTests {
    private let now = Fixtures.date(2026, 11, 18, 10, 30)
    private let firstOfDecember = Fixtures.date(2026, 12, 1, 0)

    @Test func rangeIsTheRawWindowToTheEndOfTheMonth() {
        let range = RetentionWindow.entryDates(now: now, timeZone: Fixtures.jakarta)
        #expect(range.lowerBound == Fixtures.date(2025, 11, 1, 0))
        #expect(range.upperBound < firstOfDecember)
        #expect(range.upperBound > Fixtures.date(2026, 11, 30, 23, 59, 59))
        #expect(RetentionWindow.entryLimit(now: now, timeZone: Fixtures.jakarta) == firstOfDecember)
    }

    /// Upcoming days of this month are allowed; the next month is not.
    @Test func boundaries() {
        let range = RetentionWindow.entryDates(now: now, timeZone: Fixtures.jakarta)
        #expect(range.contains(Fixtures.date(2026, 11, 25)))
        #expect(range.contains(Fixtures.date(2026, 11, 30, 23, 59, 59)))
        #expect(range.contains(firstOfDecember.addingTimeInterval(-0.001)), "the last instant of the month is allowed")
        #expect(!range.contains(firstOfDecember), "the first instant of next month is not")
        #expect(range.contains(Fixtures.date(2025, 11, 1, 0)))
        #expect(!range.contains(Fixtures.date(2025, 10, 31, 23, 59, 59)))
    }

    @Test func decemberRollsIntoJanuary() {
        let december = Fixtures.date(2026, 12, 31, 23)
        #expect(RetentionWindow.entryLimit(now: december, timeZone: Fixtures.jakarta) == Fixtures.date(2027, 1, 1, 0))
        #expect(RetentionWindow.entryDates(now: december, timeZone: Fixtures.jakarta).lowerBound == Fixtures.date(2025, 12, 1, 0))
    }

    @Test func rangeFollowsTheTimeZone() {
        // 1 Dec 2026 03:00 Jakarta is still 30 Nov in Los Angeles.
        let instant = Fixtures.date(2026, 12, 1, 3, in: Fixtures.jakarta)
        #expect(RetentionWindow.entryLimit(now: instant, timeZone: Fixtures.jakarta) == Fixtures.date(2027, 1, 1, 0))
        #expect(
            RetentionWindow.entryLimit(now: instant, timeZone: Fixtures.losAngeles)
                == Fixtures.date(2026, 12, 1, 0, in: Fixtures.losAngeles)
        )
        #expect(
            RetentionWindow.entryDates(now: instant, timeZone: Fixtures.losAngeles).lowerBound
                == Fixtures.date(2025, 11, 1, 0, in: Fixtures.losAngeles)
        )
    }

    /// Editing a transaction dated just before the window (possible until Phase 8 purges it)
    /// must not move it: the range widens to keep its date.
    @Test func rangeWidensToKeepAnExistingOlderDate() {
        let old = Fixtures.date(2025, 10, 31, 20)
        #expect(RetentionWindow.entryDates(now: now, timeZone: Fixtures.jakarta, keeping: old).lowerBound == old)
        let recent = Fixtures.date(2026, 11, 2)
        #expect(RetentionWindow.entryDates(now: now, timeZone: Fixtures.jakarta, keeping: recent).lowerBound == Fixtures.date(2025, 11, 1, 0))
    }

    /// A transaction dated after this month (recorded in a time zone ahead of this one) keeps its date:
    /// the range widens upward to include it.
    @Test func rangeWidensToKeepAnExistingLaterDate() {
        let ahead = Fixtures.date(2026, 12, 1, 6, 30)
        let range = RetentionWindow.entryDates(now: now, timeZone: Fixtures.jakarta, keeping: ahead)
        #expect(range.upperBound == ahead)
        #expect(range.lowerBound == Fixtures.date(2025, 11, 1, 0))
        #expect(RetentionWindow.clampedEntryDate(ahead, now: now, timeZone: Fixtures.jakarta, keeping: ahead) == ahead)
        let further = Fixtures.date(2026, 12, 9)
        #expect(RetentionWindow.clampedEntryDate(further, now: now, timeZone: Fixtures.jakarta, keeping: ahead) == ahead)
        let recent = Fixtures.date(2026, 11, 2)
        #expect(RetentionWindow.entryDates(now: now, timeZone: Fixtures.jakarta, keeping: recent).upperBound < firstOfDecember)
    }

    @Test func clamping() {
        let inside = Fixtures.date(2026, 11, 28, 8)
        #expect(RetentionWindow.clampedEntryDate(inside, now: now, timeZone: Fixtures.jakarta) == inside)

        let nextMonth = Fixtures.date(2026, 12, 3)
        let clamped = RetentionWindow.clampedEntryDate(nextMonth, now: now, timeZone: Fixtures.jakarta)
        #expect(clamped < firstOfDecember && clamped > Fixtures.date(2026, 11, 30, 23, 59, 59))

        let tooOld = Fixtures.date(2024, 5, 5)
        #expect(RetentionWindow.clampedEntryDate(tooOld, now: now, timeZone: Fixtures.jakarta) == Fixtures.date(2025, 11, 1, 0))
        #expect(RetentionWindow.clampedEntryDate(tooOld, now: now, timeZone: Fixtures.jakarta, keeping: tooOld) == tooOld)
    }
}
