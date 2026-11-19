import Foundation
import KemanayaCore
import Testing

/// Tren's month-over-month bars (D-051): pengeluaran and pemasukan for six months ending at the selected one.
struct MonthlyFlowSeriesTests {
    private let november = MonthKey(year: 2026, month: 11)

    private func snapshot(_ amount: Int64, _ kind: TransactionKind, _ group: ExpenseGroup?, _ date: Date) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: kind, group: group, subcategoryID: UUID(), date: date)
    }

    @Test func sixMonthsOldestFirstEndingAtTheSelectedMonth() {
        let series = MonthlyFlowSeries([TransactionSnapshot](), ending: november, timeZone: Fixtures.jakarta)
        #expect(series.months.map(\.month) == (6...11).map { MonthKey(year: 2026, month: $0) })
        #expect(series.selected == november)
        #expect(series.months.last?.month == series.selected)
        #expect(series.isEmpty)
        #expect(series.largestAmount == 0)
    }

    @Test func crossesTheYearBoundary() {
        let months = MonthlyFlowSeries.months(ending: MonthKey(year: 2027, month: 2))
        #expect(months == [
            MonthKey(year: 2026, month: 9), MonthKey(year: 2026, month: 10), MonthKey(year: 2026, month: 11),
            MonthKey(year: 2026, month: 12), MonthKey(year: 2027, month: 1), MonthKey(year: 2027, month: 2),
        ])
        #expect(MonthlyFlowSeries.months(ending: november, length: 0) == [november], "at least one month")
    }

    @Test func sumsExpensesAndIncomePerMonth() {
        let series = MonthlyFlowSeries(
            [
                snapshot(8_500_000, .income, nil, Fixtures.date(2026, 11, 1, 0)),
                snapshot(1_250_000, .expense, .kebutuhan, Fixtures.date(2026, 11, 10)),
                snapshot(431_500, .expense, .keinginan, Fixtures.date(2026, 11, 30, 23, 59, 59)),
                snapshot(2_000_000, .expense, .kebutuhan, Fixtures.date(2026, 6, 1, 0)), // the oldest month
                snapshot(9_999, .expense, .kebutuhan, Fixtures.date(2026, 5, 31, 23, 59, 59)), // before the series
                snapshot(7_777, .expense, .keinginan, Fixtures.date(2026, 12, 1, 0)), // after it
                snapshot(5_000, .expense, nil, Fixtures.date(2026, 11, 2)), // invalid: no group
            ],
            ending: november,
            timeZone: Fixtures.jakarta
        )
        #expect(series.months.last == MonthlyFlow(month: november, expenses: 1_681_500, income: 8_500_000))
        #expect(series.months.first == MonthlyFlow(month: MonthKey(year: 2026, month: 6), expenses: 2_000_000, income: 0))
        #expect(series.months[1...4].allSatisfy { $0.expenses == 0 && $0.income == 0 })
        #expect(series.largestAmount == 8_500_000)
        #expect(!series.isEmpty)
    }

    @Test func monthsAreTakenInTheInjectedTimeZone() {
        // 1 Nov 2026 06:00 in Jakarta is 31 Oct in Los Angeles.
        let transaction = snapshot(25_000, .expense, .kebutuhan, Fixtures.date(2026, 11, 1, 6))
        let jakarta = MonthlyFlowSeries([transaction], ending: november, timeZone: Fixtures.jakarta)
        #expect(jakarta.months.last?.expenses == 25_000)
        let losAngeles = MonthlyFlowSeries([transaction], ending: november, timeZone: Fixtures.losAngeles)
        #expect(losAngeles.months.last?.expenses == 0)
        #expect(losAngeles.months[4].expenses == 25_000, "October")
    }

    @Test func fetchRangeCoversExactlyTheSixMonths() {
        let range = MonthlyFlowSeries.dateRange(ending: november, timeZone: Fixtures.jakarta)
        #expect(range.lowerBound == Fixtures.date(2026, 6, 1, 0))
        #expect(range.upperBound == Fixtures.date(2026, 12, 1, 0))
    }
}
