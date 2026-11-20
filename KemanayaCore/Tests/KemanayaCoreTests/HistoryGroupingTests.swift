import Foundation
import KemanayaCore
import Testing

/// History's month and day grouping with totals (D-053).
struct HistoryGroupingTests {
    private let makan = UUID()
    private let gaji = UUID()

    private func spend(_ amount: Int64, _ date: Date) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .expense, group: .kebutuhan, subcategoryID: makan, date: date)
    }

    private func earn(_ amount: Int64, _ date: Date) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .income, group: nil, subcategoryID: gaji, date: date)
    }

    @Test func groupsByMonthThenDayNewestFirstWithTotals() {
        // Newest first, as the fetch sorts them.
        let entries = [
            spend(18_000, Fixtures.date(2026, 11, 19, 20)),
            spend(30_000, Fixtures.date(2026, 11, 19, 8)),
            earn(8_500_000, Fixtures.date(2026, 11, 1, 9)),
            spend(25_000, Fixtures.date(2026, 11, 1, 7)),
            spend(40_000, Fixtures.date(2026, 10, 31, 23, 59, 59)),
        ]
        let months = HistoryGrouping.months(entries, timeZone: Fixtures.jakarta)

        #expect(months.map(\.month) == [MonthKey(year: 2026, month: 11), MonthKey(year: 2026, month: 10)])
        let november = months[0]
        #expect(november.days.map(\.day) == [DayKey(year: 2026, month: 11, day: 19), DayKey(year: 2026, month: 11, day: 1)])
        #expect(november.totals == HistoryTotals(expenses: 73_000, income: 8_500_000))

        let thursday = november.days[0]
        #expect(thursday.entries.map(\.amount) == [18_000, 30_000], "a day keeps the input order")
        #expect(thursday.totals == HistoryTotals(expenses: 48_000, income: 0))
        #expect(!thursday.totals.hasIncome)
        #expect(thursday.totals.hasExpenses)

        let first = november.days[1]
        #expect(first.totals == HistoryTotals(expenses: 25_000, income: 8_500_000), "income is kept apart, never netted")
        #expect(first.totals.hasIncome)

        #expect(months[1].days.map(\.day) == [DayKey(year: 2026, month: 10, day: 31)])
        #expect(months[1].totals.expenses == 40_000)
    }

    /// Unsorted input still gives months and days newest first.
    @Test func sortsMonthsAndDaysWhateverTheInputOrder() {
        let entries = [
            spend(1_000, Fixtures.date(2026, 9, 2)),
            spend(2_000, Fixtures.date(2026, 11, 3)),
            spend(3_000, Fixtures.date(2026, 9, 20)),
            spend(4_000, Fixtures.date(2025, 12, 31)),
            spend(5_000, Fixtures.date(2026, 11, 30)),
        ]
        let months = HistoryGrouping.months(entries, timeZone: Fixtures.jakarta)
        #expect(months.map(\.month.description) == ["2026-11", "2026-09", "2025-12"], "across a year boundary too")
        #expect(months[0].days.map(\.day.day) == [30, 3])
        #expect(months[1].days.map(\.day.day) == [20, 2])
    }

    /// Days are bucketed in the given zone: the same instant is a different day in Los Angeles.
    @Test func bucketsDaysInTheTimeZone() {
        let instant = Fixtures.date(2026, 11, 1, 6) // 1 Nov 06:00 Jakarta = 31 Oct 16:00 Los Angeles
        let jakarta = HistoryGrouping.months([spend(10_000, instant)], timeZone: Fixtures.jakarta)
        let losAngeles = HistoryGrouping.months([spend(10_000, instant)], timeZone: Fixtures.losAngeles)
        #expect(jakarta.first?.days.first?.day == DayKey(year: 2026, month: 11, day: 1))
        #expect(losAngeles.first?.days.first?.day == DayKey(year: 2026, month: 10, day: 31))
        #expect(losAngeles.first?.month == MonthKey(year: 2026, month: 10))
    }

    /// History's fetch has no upper date bound (D-057): an entry dated in a later month (after a time-zone
    /// change, D-044) gets its own month, placed first.
    @Test func aLaterMonthComesFirst() {
        let entries = [
            spend(10_000, Fixtures.date(2026, 11, 19)),
            spend(20_000, Fixtures.date(2026, 12, 1, 0)),
            spend(30_000, Fixtures.date(2026, 10, 5)),
            spend(40_000, Fixtures.date(2027, 1, 2)),
        ]
        let months = HistoryGrouping.months(entries, timeZone: Fixtures.jakarta)
        #expect(months.map(\.month.description) == ["2027-01", "2026-12", "2026-11", "2026-10"])
        #expect(months[1].days.map(\.day) == [DayKey(year: 2026, month: 12, day: 1)])
        #expect(months[1].totals.expenses == 20_000)
    }

    @Test func emptyInputHasNoMonths() {
        #expect(HistoryGrouping.months([TransactionSnapshot](), timeZone: Fixtures.jakarta).isEmpty)
    }

    /// A day with only income has no pengeluaran to show, just the "+Rp…".
    @Test func incomeOnlyDay() {
        let months = HistoryGrouping.months([earn(500_000, Fixtures.date(2026, 11, 5))], timeZone: Fixtures.jakarta)
        let totals = months[0].days[0].totals
        #expect(totals == HistoryTotals(expenses: 0, income: 500_000))
        #expect(!totals.hasExpenses)
        #expect(totals.hasIncome)
    }

    @Test func dayKeyStartAndOrder() {
        let day = DayKey(containing: Fixtures.date(2026, 11, 19, 23, 59, 59), timeZone: Fixtures.jakarta)
        #expect(day == DayKey(year: 2026, month: 11, day: 19))
        #expect(day.start(in: Fixtures.jakarta) == Fixtures.date(2026, 11, 19, 0))
        #expect(day.monthKey == MonthKey(year: 2026, month: 11))
        #expect(DayKey(year: 2026, month: 10, day: 31) < DayKey(year: 2026, month: 11, day: 1))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
        #expect(day.description == "2026-11-19")
        let losAngeles = Calendar.gregorian(in: Fixtures.losAngeles)
        #expect(DayKey(containing: Fixtures.date(2026, 11, 1, 6), calendar: losAngeles) == DayKey(year: 2026, month: 10, day: 31))
        #expect(
            DayKey(containing: Fixtures.date(2026, 11, 1, 6), calendar: losAngeles)
                == DayKey(containing: Fixtures.date(2026, 11, 1, 6), timeZone: Fixtures.losAngeles),
            "the calendar init agrees with the time-zone init"
        )
    }

    /// The real models group the same way, so the screen can list them directly.
    @Test func groupsModels() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let kopi = try store.subcategory(named: "Kopi")
        let first = MoneyTransaction(amount: 18_000, subcategory: kopi, date: Fixtures.date(2026, 11, 19))
        let second = MoneyTransaction(amount: 22_000, subcategory: kopi, date: Fixtures.date(2026, 11, 18))
        store.context.insert(first)
        store.context.insert(second)
        let months = HistoryGrouping.months([first, second], timeZone: Fixtures.jakarta)
        #expect(months.count == 1)
        #expect(months[0].days.map { $0.entries.map(\.amount) } == [[18_000], [22_000]])
        #expect(months[0].totals.expenses == 40_000)
    }
}
