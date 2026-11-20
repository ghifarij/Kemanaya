import Foundation
import KemanayaCore
import SwiftData
import Testing

/// The one source of a month's totals (D-055, D-059): raw inside the window, rollups before it.
struct MonthTotalsTests {
    private let zone = Fixtures.jakarta
    private let makan = UUID()
    private let kopi = UUID()
    private let gaji = UUID()

    private func expense(_ amount: Int64, _ id: UUID, _ group: ExpenseGroup, _ date: Date) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .expense, group: group, subcategoryID: id, date: date)
    }

    private func rollup(_ month: MonthKey, _ id: UUID, _ kind: TransactionKind, _ group: ExpenseGroup?, _ total: Int64, count: Int = 1) -> RollupSnapshot {
        RollupSnapshot(month: month, subcategoryID: id, kind: kind, group: group, total: total, count: count, name: "x", emoji: "x")
    }

    @Test func readsRawInsideTheWindowAndRollupsBeforeIt() {
        let november2025 = MonthKey(year: 2025, month: 11) // the window's first month in Nov 2026
        let october2025 = november2025.previous // purged: rollups only
        let totals = MonthTotals(
            transactions: [
                expense(30_000, makan, .kebutuhan, Fixtures.date(2025, 11, 1, 0)),
                expense(18_000, kopi, .keinginan, Fixtures.date(2025, 11, 30, 23, 59)),
            ],
            rollups: [
                rollup(october2025, makan, .expense, .kebutuhan, 1_250_000, count: 20),
                rollup(october2025, kopi, .expense, .keinginan, 240_000, count: 12),
                rollup(october2025, gaji, .income, nil, 8_500_000),
            ],
            timeZone: zone
        )
        let raw = totals.summary(for: november2025)
        #expect(raw.kebutuhan == 30_000)
        #expect(raw.keinginan == 18_000)
        #expect(raw.income == 0)

        let rolledUp = totals.summary(for: october2025)
        #expect(rolledUp.kebutuhan == 1_250_000)
        #expect(rolledUp.keinginan == 240_000)
        #expect(rolledUp.expenses == 1_490_000)
        #expect(rolledUp.income == 8_500_000)
        #expect(rolledUp.total(for: makan) == 1_250_000)
        #expect(rolledUp.subcategories.first { $0.subcategoryID == kopi }?.count == 12)
        #expect(totals.months == [october2025, november2025])

        #expect(totals.summary(for: october2025.previous).subcategories.isEmpty, "a month with neither is empty")
    }

    /// The window just moved and retention hasn't run yet: the month's raw rows still count.
    @Test func aMonthNotYetRolledUpStillCountsItsRawRows() {
        let october = MonthKey(year: 2025, month: 10)
        let totals = MonthTotals(
            transactions: [expense(40_000, makan, .kebutuhan, Fixtures.date(2025, 10, 5))],
            rollups: [rollup(october, makan, .expense, .kebutuhan, 10_000)],
            timeZone: zone
        )
        #expect(totals.summary(for: october).total(for: makan) == 50_000, "what retention would leave")
    }

    /// Transactions are bucketed in the given zone: 00:30 on 1 Nov in Jakarta is November.
    @Test func bucketsTransactionsInTheTimeZone() {
        let totals = MonthTotals(
            transactions: [expense(22_000, makan, .kebutuhan, Fixtures.date(2025, 11, 1, 0, 30))],
            rollups: [RollupSnapshot](),
            timeZone: zone
        )
        #expect(totals.summary(for: MonthKey(year: 2025, month: 11)).kebutuhan == 22_000)
        #expect(totals.summary(for: MonthKey(year: 2025, month: 10)).kebutuhan == 0)
    }

    /// The six-month chart reaches before the window without a false Rp0 (D-055).
    @Test func monthlyFlowSeriesReadsRollupsForPurgedMonths() {
        let selected = MonthKey(year: 2025, month: 12)
        let totals = MonthTotals(
            transactions: [
                expense(100_000, makan, .kebutuhan, Fixtures.date(2025, 12, 2)),
                TransactionSnapshot(amount: 8_000_000, kind: .income, group: nil, subcategoryID: gaji, date: Fixtures.date(2025, 11, 25)),
            ],
            rollups: [
                rollup(MonthKey(year: 2025, month: 7), makan, .expense, .kebutuhan, 900_000),
                rollup(MonthKey(year: 2025, month: 10), gaji, .income, nil, 8_500_000),
                rollup(MonthKey(year: 2025, month: 10), kopi, .expense, .keinginan, 75_000),
                rollup(MonthKey(year: 2025, month: 6), makan, .expense, .kebutuhan, 1), // outside the six months
            ],
            timeZone: zone
        )
        let series = MonthlyFlowSeries(totals: totals, ending: selected)
        #expect(series.months.map(\.month.month) == [7, 8, 9, 10, 11, 12])
        #expect(series.months.map(\.expenses) == [900_000, 0, 0, 75_000, 0, 100_000])
        #expect(series.months.map(\.income) == [0, 0, 0, 8_500_000, 8_000_000, 0])
    }

    /// The subcategory detail and Home's cards compare against a purged month's rollup.
    @Test func comparisonsReadThePreviousMonthsRollup() {
        let october = MonthKey(year: 2025, month: 10)
        let totals = MonthTotals(
            transactions: [TransactionSnapshot](),
            rollups: [rollup(october, kopi, .expense, .keinginan, 240_000, count: 12)],
            timeZone: zone
        )
        let current = [expense(18_000, kopi, .keinginan, Fixtures.date(2025, 11, 3))]
        let detail = SubcategoryDetail(
            subcategoryID: kopi,
            current: current,
            previousTotal: totals.summary(for: october).total(for: kopi),
            monthlyBudget: nil
        )
        #expect(detail.previousTotal == 240_000)
        #expect(detail.comparison.direction == .down)

        let home = HomeOverview(
            current: current,
            previous: totals.summary(for: october),
            pins: [HomeOverview.Pin(id: kopi, monthlyBudget: nil)],
            groupBudgets: [:]
        )
        #expect(home.card(for: kopi)?.comparison == MonthComparison(current: 18_000, previous: 240_000))
    }

    /// The ledger fetches both kinds of rows for a span of months.
    @Test func ledgerFetchesRawAndRollupsForTheSpan() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let makanModel = try store.subcategory(named: "Makan")
        store.context.insert(MoneyTransaction(amount: 30_000, subcategory: makanModel, date: Fixtures.date(2025, 11, 2)))
        store.context.insert(MoneyTransaction(amount: 99, subcategory: makanModel, date: Fixtures.date(2025, 12, 1, 0)))
        store.context.insert(MonthlyRollup(
            month: MonthKey(year: 2025, month: 10), subcategoryID: makanModel.id, total: 1_000_000, count: 30,
            name: "Makan", emoji: "🍚", kind: .expense, group: .kebutuhan
        ))
        store.context.insert(MonthlyRollup(
            month: MonthKey(year: 2025, month: 9), subcategoryID: makanModel.id, total: 7, count: 1,
            name: "Makan", emoji: "🍚", kind: .expense, group: .kebutuhan
        ))
        try store.context.save()

        let ledger = Ledger(context: store.context, timeZone: zone)
        let totals = try ledger.monthTotals(from: MonthKey(year: 2025, month: 10), through: MonthKey(year: 2025, month: 11))
        #expect(totals.months == [MonthKey(year: 2025, month: 10), MonthKey(year: 2025, month: 11)], "nothing outside the span")
        #expect(totals.summary(for: MonthKey(year: 2025, month: 10)).kebutuhan == 1_000_000)
        #expect(totals.summary(for: MonthKey(year: 2025, month: 11)).kebutuhan == 30_000)
        #expect(try ledger.earliestMonthWithData() == MonthKey(year: 2025, month: 9))
    }

    @Test func earliestMonthWithDataComesFromTransactionsToo() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let ledger = Ledger(context: store.context, timeZone: zone)
        #expect(try ledger.earliestMonthWithData() == nil)
        store.context.insert(MoneyTransaction(amount: 1, subcategory: try store.subcategory(named: "Makan"), date: Fixtures.date(2025, 11, 1, 0, 30)))
        store.context.insert(MonthlyRollup(
            month: MonthKey(year: 2025, month: 12), subcategoryID: UUID(), total: 1, count: 1,
            name: "", emoji: "", kind: .expense, group: .kebutuhan
        ))
        try store.context.save()
        #expect(try ledger.earliestMonthWithData() == MonthKey(year: 2025, month: 11))
    }
}
