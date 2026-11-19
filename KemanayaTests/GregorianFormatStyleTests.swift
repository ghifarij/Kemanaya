import Foundation
import KemanayaCore
import Testing
@testable import Kemanaya

/// Month titles format the month's start in the zone it was bucketed in, so they name the same month
/// as the totals below them whatever the device zone is.
@MainActor
struct GregorianFormatStyleTests {
    private let locale = Locale(identifier: "en_US")
    private let kiritimati = TimeZone(identifier: "Pacific/Kiritimati")! // UTC+14
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    @Test func monthTitleUsesTheBucketingZone() {
        // 1 Nov 2026 00:00 in Kiritimati is still 31 Oct in Los Angeles.
        let start = MonthKey(year: 2026, month: 11).start(in: kiritimati)
        #expect(start.formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: kiritimati).month(.wide).year()) == "November 2026")
        #expect(start.formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: losAngeles).month(.wide).year()) == "October 2026")
    }

    @Test func calendarIsGregorianInTheGivenZone() {
        let style = Date.FormatStyle.gregorian(locale: locale, timeZone: kiritimati)
        #expect(style.calendar.identifier == .gregorian)
        #expect(style.calendar.timeZone == kiritimati)
        #expect(style.timeZone == kiritimati)
    }
}
