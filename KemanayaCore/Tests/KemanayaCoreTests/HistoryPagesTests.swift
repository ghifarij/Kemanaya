import Foundation
import KemanayaCore
import SwiftData
import Testing

/// History's paged fetch over the 13-month raw window (D-017, D-053).
struct HistoryPagesTests {
    private let november = MonthKey(year: 2026, month: 11)

    @Test func firstPageIsThisMonthAndLastMonth() {
        let pages = HistoryPages(current: november)
        #expect(pages.latest == november)
        #expect(pages.earliest == MonthKey(year: 2025, month: 11), "the 13-month window")
        #expect(pages.oldestLoaded == MonthKey(year: 2026, month: 10))
        #expect(pages.loadedMonths.map(\.description) == ["2026-11", "2026-10"])
        #expect(pages.hasMore)
    }

    @Test func loadsPagesUntilTheWindowStart() {
        var pages = HistoryPages(current: november)
        var loads = 0
        while pages.hasMore {
            pages.loadNextPage()
            loads += 1
            #expect(loads <= 12, "loading stops")
        }
        #expect(loads == 6, "13 months: 2 at first, then 2 per page, the last page has 1")
        #expect(pages.oldestLoaded == pages.earliest)
        #expect(pages.loadedMonths.count == 13)
        #expect(pages.loadedMonths.first == november)
        #expect(pages.loadedMonths.last == MonthKey(year: 2025, month: 11))
        pages.loadNextPage()
        #expect(pages.oldestLoaded == pages.earliest, "nothing past the window")
    }

    /// Two asks for the page after the same month load it once.
    @Test func asksForTheSamePageLoadItOnce() {
        var pages = HistoryPages(current: november)
        let seen = pages.oldestLoaded
        pages.loadNextPage(after: seen)
        pages.loadNextPage(after: seen)
        #expect(pages.oldestLoaded == MonthKey(year: 2026, month: 8))
        pages.loadNextPage(after: pages.oldestLoaded)
        #expect(pages.oldestLoaded == MonthKey(year: 2026, month: 6))
    }

    @Test func clampsTheOldestLoadedMonthIntoTheWindow() {
        #expect(HistoryPages(current: november, oldestLoaded: MonthKey(year: 2020, month: 1)).oldestLoaded == MonthKey(year: 2025, month: 11))
        #expect(HistoryPages(current: november, oldestLoaded: MonthKey(year: 2027, month: 1)).oldestLoaded == november)
    }

    /// A new month slides the window and keeps what was loaded, as far as it is still inside it.
    @Test func movesToANewMonth() {
        let first = HistoryPages(current: november)
        let december = first.moved(to: november.next)
        #expect(december.latest == MonthKey(year: 2026, month: 12))
        #expect(december.earliest == MonthKey(year: 2025, month: 12))
        #expect(december.oldestLoaded == MonthKey(year: 2026, month: 10), "October stays loaded")
        #expect(first.moved(to: november) == first)

        // Going back a month (the time zone moved back across a month boundary, D-044): the window
        // slides back, and what was loaded stays loaded as far as it is still inside it.
        let october = first.moved(to: november.previous)
        #expect(october.latest == MonthKey(year: 2026, month: 10))
        #expect(october.earliest == MonthKey(year: 2025, month: 10))
        #expect(october.oldestLoaded == MonthKey(year: 2026, month: 9), "a full first page below October")
        #expect(october.loadedMonths.map(\.description) == ["2026-10", "2026-09"])
        var deep = HistoryPages(current: november)
        deep.loadNextPage()
        #expect(deep.moved(to: november.previous).oldestLoaded == MonthKey(year: 2026, month: 8), "August stays loaded")

        var all = HistoryPages(current: november)
        while all.hasMore { all.loadNextPage() }
        let moved = all.moved(to: november.next)
        #expect(moved.oldestLoaded == moved.earliest, "November 2025 left the window")
        #expect(!moved.hasMore)
    }

    /// From the oldest loaded month on, with no upper bound (D-057).
    @Test func dateRangeStartsAtTheOldestLoadedMonthAndHasNoEnd() {
        let pages = HistoryPages(current: november)
        let range = pages.dateRange(in: Fixtures.jakarta)
        #expect(range.lowerBound == Fixtures.date(2026, 10, 1, 0))
        #expect(range.upperBound == .distantFuture)
        #expect(range.contains(Fixtures.date(2027, 3, 1)), "a later month is inside")
    }

    @Test func fetchesTheLoadedMonthsNewestFirst() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let makan = try store.subcategory(named: "Makan")
        let entries: [(Int64, Date)] = [
            (1, Fixtures.date(2026, 11, 30, 23, 59, 59)), // last second of the current month
            (2, Fixtures.date(2026, 11, 2)),
            (3, Fixtures.date(2026, 10, 1, 0)), // first instant of the first page
            (4, Fixtures.date(2026, 9, 30, 23, 59, 59)), // the next page
            (5, Fixtures.date(2026, 8, 15)),
            (6, Fixtures.date(2025, 11, 1, 0)), // the window's first instant
            (7, Fixtures.date(2025, 10, 31, 23, 59, 59)), // before the window
            (8, Fixtures.date(2026, 12, 1, 0)), // after the current month: shown at the top (D-057)
        ]
        for (amount, date) in entries {
            store.context.insert(MoneyTransaction(amount: amount, subcategory: makan, date: date))
        }
        try store.context.save()
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)

        var pages = HistoryPages(current: november)
        #expect(try ledger.historyTransactions(pages).map(\.amount) == [8, 1, 2, 3], "a later month is never hidden")
        pages.loadNextPage()
        #expect(try ledger.historyTransactions(pages).map(\.amount) == [8, 1, 2, 3, 4, 5])
        while pages.hasMore { pages.loadNextPage() }
        #expect(try ledger.historyTransactions(pages).map(\.amount) == [8, 1, 2, 3, 4, 5, 6], "never before the window")
        let months = HistoryGrouping.months(try ledger.historyTransactions(pages), timeZone: Fixtures.jakarta)
        #expect(months.first?.month == MonthKey(year: 2026, month: 12), "the later month is placed first")
    }

    /// Same-day ties: the newest entry first.
    @Test func tiesOnDateShowTheNewestEntryFirst() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let kopi = try store.subcategory(named: "Kopi")
        let date = Fixtures.date(2026, 11, 19, 9)
        store.context.insert(MoneyTransaction(amount: 1, subcategory: kopi, date: date, createdAt: Fixtures.date(2026, 11, 19, 9)))
        store.context.insert(MoneyTransaction(amount: 2, subcategory: kopi, date: date, createdAt: Fixtures.date(2026, 11, 19, 10)))
        try store.context.save()
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        #expect(try ledger.historyTransactions(HistoryPages(current: november)).map(\.amount) == [2, 1])
    }
}
