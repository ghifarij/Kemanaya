import Foundation
import KemanayaCore
import Testing

/// Tren's Harian / Mingguan buckets (D-051): Kebutuhan and Keinginan apart, filtered, Monday weeks
/// clipped to the month, Gregorian, in the injected time zone.
struct SpendingTrendTests {
    private let november = MonthKey(year: 2026, month: 11)
    private let makan = UUID()
    private let kopi = UUID()

    private func expense(_ amount: Int64, _ group: ExpenseGroup, _ date: Date) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .expense, group: group, subcategoryID: group == .kebutuhan ? makan : kopi, date: date)
    }

    // MARK: - Week rule

    /// November 2026 starts on a Sunday: the 1st is a week of its own, and the 30th (a Monday) too.
    @Test func weeksStartOnMondayAndAreClippedToTheMonth() {
        #expect(SpendingTrend.weeks(of: november) == [1...1, 2...8, 9...15, 16...22, 23...29, 30...30])
    }

    @Test(arguments: [
        // February 2027 starts on a Monday and has 28 days: exactly four full weeks.
        (MonthKey(year: 2027, month: 2), [1...7, 8...14, 15...21, 22...28]),
        // February 2026 starts on a Sunday.
        (MonthKey(year: 2026, month: 2), [1...1, 2...8, 9...15, 16...22, 23...28]),
        // Leap February 2024 starts on a Thursday.
        (MonthKey(year: 2024, month: 2), [1...4, 5...11, 12...18, 19...25, 26...29]),
        // December 2026 starts on a Tuesday; the last week ends on the 31st, not in January.
        (MonthKey(year: 2026, month: 12), [1...6, 7...13, 14...20, 21...27, 28...31]),
        // March 2026 starts on a Sunday and has 31 days: six buckets, the most a month can have.
        (MonthKey(year: 2026, month: 3), [1...1, 2...8, 9...15, 16...22, 23...29, 30...31]),
    ])
    func weeksAtMonthEdges(month: MonthKey, expected: [ClosedRange<Int>]) {
        let weeks = SpendingTrend.weeks(of: month)
        #expect(weeks == expected)
        #expect(weeks.first?.lowerBound == 1)
        #expect(weeks.last?.upperBound == SpendingTrend.dayCount(of: month), "every day is covered")
        #expect(weeks.reduce(0) { $0 + $1.count } == SpendingTrend.dayCount(of: month), "no day twice")
    }

    @Test func dayCounts() {
        #expect(SpendingTrend.dayCount(of: november) == 30)
        #expect(SpendingTrend.dayCount(of: MonthKey(year: 2026, month: 12)) == 31)
        #expect(SpendingTrend.dayCount(of: MonthKey(year: 2026, month: 2)) == 28)
        #expect(SpendingTrend.dayCount(of: MonthKey(year: 2024, month: 2)) == 29)
    }

    /// The device's first weekday (Sunday in the US) doesn't change the rule.
    @Test func weekRuleIgnoresTheDevicesFirstWeekday() {
        #expect(Calendar.gregorian(in: Fixtures.losAngeles).firstWeekday == 1, "Gregorian defaults to Sunday")
        #expect(SpendingTrend.weeks(of: november).first == 1...1)
    }

    // MARK: - Daily

    @Test func dailyBucketsSplitTheGroupsAndCoverEveryDay() {
        let trend = SpendingTrend(
            [
                expense(50_000, .kebutuhan, Fixtures.date(2026, 11, 1, 0)), // first instant
                expense(20_000, .keinginan, Fixtures.date(2026, 11, 1, 23, 59, 59)),
                expense(30_000, .kebutuhan, Fixtures.date(2026, 11, 15)),
                expense(10_000, .keinginan, Fixtures.date(2026, 11, 30, 23, 59, 59)), // last second
                expense(99_000, .kebutuhan, Fixtures.date(2026, 10, 31, 23, 59, 59)), // October
                expense(77_000, .keinginan, Fixtures.date(2026, 12, 1, 0)), // December
                TransactionSnapshot(amount: 8_500_000, kind: .income, group: nil, subcategoryID: UUID(), date: Fixtures.date(2026, 11, 2)),
            ],
            month: november, timeZone: Fixtures.jakarta, granularity: .daily
        )
        #expect(trend.buckets.count == 30)
        #expect(trend.buckets.map(\.firstDay) == Array(1...30))
        #expect(trend.buckets.allSatisfy { $0.firstDay == $0.lastDay })
        #expect(trend.buckets[0] == SpendingBucket(index: 0, firstDay: 1, lastDay: 1, kebutuhan: 50_000, keinginan: 20_000))
        #expect(trend.buckets[14].kebutuhan == 30_000)
        #expect(trend.buckets[29].keinginan == 10_000)
        #expect(trend.buckets[1].total == 0, "income is never a bar")
        #expect(trend.total == 110_000, "other months are left out")
        #expect(!trend.isEmpty)
    }

    @Test func followsTheFilter() {
        let transactions = [
            expense(50_000, .kebutuhan, Fixtures.date(2026, 11, 3)),
            expense(20_000, .keinginan, Fixtures.date(2026, 11, 3)),
        ]
        let kebutuhan = SpendingTrend(transactions, month: november, timeZone: Fixtures.jakarta, granularity: .daily, filter: .kebutuhan)
        #expect(kebutuhan.buckets[2].kebutuhan == 50_000)
        #expect(kebutuhan.buckets[2].keinginan == 0)
        let keinginan = SpendingTrend(transactions, month: november, timeZone: Fixtures.jakarta, granularity: .weekly, filter: .keinginan)
        #expect(keinginan.total == 20_000)
        #expect(keinginan.buckets[1].amount(for: .keinginan) == 20_000)
        #expect(keinginan.buckets[1].amount(for: .kebutuhan) == 0)
    }

    // MARK: - Weekly

    @Test func weeklyBucketsAddUpToTheMonth() {
        let transactions = [
            expense(10_000, .kebutuhan, Fixtures.date(2026, 11, 1)), // Sunday: week 1 alone
            expense(20_000, .kebutuhan, Fixtures.date(2026, 11, 2, 0)), // Monday 00:00: week 2
            expense(30_000, .keinginan, Fixtures.date(2026, 11, 8, 23, 59, 59)), // Sunday night: still week 2
            expense(40_000, .keinginan, Fixtures.date(2026, 11, 30)), // the last Monday: week 6
        ]
        let trend = SpendingTrend(transactions, month: november, timeZone: Fixtures.jakarta, granularity: .weekly)
        #expect(trend.buckets.map { $0.firstDay...$0.lastDay } == [1...1, 2...8, 9...15, 16...22, 23...29, 30...30])
        #expect(trend.buckets.map(\.total) == [10_000, 50_000, 0, 0, 0, 40_000])
        #expect(trend.buckets[1].kebutuhan == 20_000 && trend.buckets[1].keinginan == 30_000)
        let daily = SpendingTrend(transactions, month: november, timeZone: Fixtures.jakarta, granularity: .daily)
        #expect(trend.total == daily.total)
        #expect(trend.buckets.map(\.index) == Array(0..<6))
    }

    /// Days are taken in the injected zone: 1 Nov 06:00 Jakarta is still 31 Oct in Los Angeles.
    @Test func bucketsInTheInjectedTimeZone() {
        let transaction = expense(25_000, .kebutuhan, Fixtures.date(2026, 11, 1, 6))
        let jakarta = SpendingTrend([transaction], month: november, timeZone: Fixtures.jakarta, granularity: .daily)
        #expect(jakarta.buckets[0].total == 25_000)
        let losAngelesNovember = SpendingTrend([transaction], month: november, timeZone: Fixtures.losAngeles, granularity: .daily)
        #expect(losAngelesNovember.isEmpty)
        let losAngelesOctober = SpendingTrend([transaction], month: november.previous, timeZone: Fixtures.losAngeles, granularity: .daily)
        #expect(losAngelesOctober.buckets[30].total == 25_000, "31 October")
    }

    @Test func emptyMonthHasZeroBucketsAndNoScale() {
        let trend = SpendingTrend([TransactionSnapshot](), month: november, timeZone: Fixtures.jakarta, granularity: .weekly)
        #expect(trend.isEmpty)
        #expect(trend.buckets.count == 6)
    }
}
