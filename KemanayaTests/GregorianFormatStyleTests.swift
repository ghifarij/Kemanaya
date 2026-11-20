import Foundation
import KemanayaCore
import Testing
@testable import Kemanaya

/// Month titles and Riwayat day headers format the period's start in the zone it was bucketed in, so they
/// name the same month or day as the totals below them whatever the device zone is.
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

    // MARK: - Riwayat day headers (D-053)

    private let indonesian = Locale(identifier: "id_ID")
    private let jakarta = TimeZone(identifier: "Asia/Jakarta")!

    @Test func dayHeaderInIndonesian() {
        let start = DayKey(year: 2026, month: 11, day: 19).start(in: jakarta)
        #expect(start.formatted(Date.FormatStyle.historyDay(locale: indonesian, timeZone: jakarta)) == "Kamis, 19 Nov")
    }

    /// The day's start formats as that day only in the zone it was bucketed in: 19 Nov 00:00 in Jakarta
    /// is still Wednesday 18 Nov in Los Angeles.
    @Test func dayHeaderUsesTheBucketingZone() {
        let start = DayKey(year: 2026, month: 11, day: 19).start(in: jakarta)
        #expect(start.formatted(Date.FormatStyle.historyDay(locale: indonesian, timeZone: losAngeles)) == "Rabu, 18 Nov")
        let style = Date.FormatStyle.historyDay(locale: indonesian, timeZone: jakarta)
        #expect(style.calendar.identifier == .gregorian)
        #expect(style.timeZone == jakarta)
    }
}
