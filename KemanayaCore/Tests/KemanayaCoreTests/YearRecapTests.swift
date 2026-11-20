import Foundation
import KemanayaCore
import SwiftData
import Testing

/// The yearly recap (D-059): rollups and raw rows of one year, ranked, with a year range.
struct YearRecapTests {
    private let zone = Fixtures.jakarta
    private let makan = UUID()
    private let kopi = UUID()
    private let gaji = UUID()
    private let langganan = UUID()
    private let november2026 = MonthKey(year: 2026, month: 11)

    private func rollup(_ year: Int, _ month: Int, _ id: UUID, _ kind: TransactionKind, _ group: ExpenseGroup?, _ total: Int64, name: String = "", emoji: String = "") -> RollupSnapshot {
        RollupSnapshot(month: MonthKey(year: year, month: month), subcategoryID: id, kind: kind, group: group, total: total, count: 2, name: name, emoji: emoji)
    }

    private func expense(_ amount: Int64, _ id: UUID, _ group: ExpenseGroup, _ date: Date) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .expense, group: group, subcategoryID: id, date: date)
    }

    /// 2025 seen from Nov 2026: Jan–Oct are rollups, Nov–Dec are raw. Both count, nothing else does.
    @Test func mixesRollupsAndRawRowsOfTheYear() {
        let recap = YearRecap(
            year: 2025,
            transactions: [
                expense(300_000, makan, .kebutuhan, Fixtures.date(2025, 11, 4)),
                expense(50_000, kopi, .keinginan, Fixtures.date(2025, 12, 31, 23, 30)),
                TransactionSnapshot(amount: 9_000_000, kind: .income, group: nil, subcategoryID: gaji, date: Fixtures.date(2025, 12, 25)),
                expense(1, makan, .kebutuhan, Fixtures.date(2026, 1, 1, 0)), // next year in Jakarta
            ],
            rollups: [
                rollup(2025, 1, makan, .expense, .kebutuhan, 1_000_000),
                rollup(2025, 10, makan, .expense, .kebutuhan, 1_200_000),
                rollup(2025, 10, kopi, .expense, .keinginan, 200_000),
                rollup(2025, 3, gaji, .income, nil, 8_500_000),
                rollup(2024, 12, makan, .expense, .kebutuhan, 5), // the year before
            ],
            current: november2026,
            subcategories: [:],
            timeZone: zone
        )
        #expect(recap.year == 2025)
        #expect(!recap.isYearToDate, "a completed year")
        #expect(recap.summary.kebutuhan == 2_500_000)
        #expect(recap.summary.keinginan == 250_000)
        #expect(recap.expenses == 2_750_000)
        #expect(recap.income == 17_500_000)
        #expect(recap.months.count == 12)
        #expect(recap.months.map(\.expenses) == [1_000_000, 0, 0, 0, 0, 0, 0, 0, 0, 1_400_000, 300_000, 50_000])
        #expect(recap.months.map(\.income) == [0, 0, 8_500_000, 0, 0, 0, 0, 0, 0, 0, 0, 9_000_000])
        #expect(recap.months.first?.month == MonthKey(year: 2025, month: 1))
        #expect(!recap.isEmpty)
    }

    /// Expense subcategories only, largest first, with whole percents that add up to 100.
    @Test func ranksExpenseSubcategoriesAcrossTheYear() {
        let recap = YearRecap(
            year: 2026,
            transactions: [expense(600_000, kopi, .keinginan, Fixtures.date(2026, 11, 2))],
            rollups: [
                rollup(2026, 2, makan, .expense, .kebutuhan, 500_000),
                rollup(2026, 3, makan, .expense, .kebutuhan, 400_000),
                rollup(2026, 4, gaji, .income, nil, 8_500_000),
            ],
            current: november2026,
            subcategories: [:],
            timeZone: zone
        )
        #expect(recap.isYearToDate)
        #expect(recap.ranking.slices.map(\.subcategoryID) == [makan, kopi], "Makan adds up across months")
        #expect(recap.ranking.slices.map(\.total) == [900_000, 600_000])
        #expect(recap.ranking.slices.map(\.percent) == [60, 40])
        #expect(!recap.ranking.slices.contains { $0.subcategoryID == gaji }, "income is never ranked")
    }

    /// The current name wins; a gone subcategory reads its newest snapshot; with neither, no label.
    @Test func labelsPreferTheCurrentNameThenTheNewestSnapshot() {
        let orphan = UUID()
        let recap = YearRecap(
            year: 2025,
            transactions: [expense(10_000, orphan, .keinginan, Fixtures.date(2025, 12, 5))],
            rollups: [
                rollup(2025, 2, kopi, .expense, .keinginan, 100_000, name: "Ngopi", emoji: "🫖"),
                rollup(2025, 3, langganan, .expense, .keinginan, 50_000, name: "Netflix", emoji: "📺"),
                rollup(2025, 5, langganan, .expense, .keinginan, 50_000, name: "Langganan", emoji: "📺"),
                rollup(2025, 4, langganan, .expense, .keinginan, 50_000, name: "Streaming", emoji: "🎞️"),
            ],
            current: november2026,
            subcategories: [kopi: SubcategoryLabel(name: "Kopi", emoji: "☕")],
            timeZone: zone
        )
        #expect(recap.labels[kopi] == SubcategoryLabel(name: "Kopi", emoji: "☕"))
        #expect(recap.labels[langganan] == SubcategoryLabel(name: "Langganan", emoji: "📺"))
        #expect(recap.labels[orphan] == nil)
    }

    @Test func aYearWithoutDataIsEmpty() {
        let recap = YearRecap(
            year: 2024, transactions: [TransactionSnapshot](), rollups: [RollupSnapshot](),
            current: november2026, subcategories: [:], timeZone: zone
        )
        #expect(recap.isEmpty)
        #expect(recap.ranking.isEmpty)
        #expect(recap.months.allSatisfy { $0.expenses == 0 && $0.income == 0 })
    }

    @Test func yearRangeRunsFromTheEarliestDataToThisYear() {
        let range = YearRecapRange(earliestMonth: MonthKey(year: 2024, month: 12), current: november2026)
        #expect(range.earliest == 2024)
        #expect(range.latest == 2026)
        #expect(range.year(before: 2026) == 2025)
        #expect(range.year(before: 2024) == nil)
        #expect(range.year(after: 2026) == nil)
        #expect(range.year(after: 2024) == 2025)
        #expect(range.clamped(2030) == 2026)
        #expect(range.clamped(1999) == 2024)

        let fresh = YearRecapRange(earliestMonth: nil, current: november2026)
        #expect(fresh.earliest == 2026 && fresh.latest == 2026)
        #expect(fresh.year(before: 2026) == nil)

        // Data dated after this year (a clock set back) never makes the range start later than now.
        let ahead = YearRecapRange(earliestMonth: MonthKey(year: 2027, month: 1), current: november2026)
        #expect(ahead.earliest == 2026)
    }

    /// Retention and the recap together: a store purged by retention gives the same recap as before.
    @Test func recapIsTheSameBeforeAndAfterRetention() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let makanModel = try store.subcategory(named: "Makan")
        let gajiModel = try store.subcategory(named: "Gaji")
        for (amount, subcategory, date) in [
            (100_000, makanModel, Fixtures.date(2025, 2, 3)),
            (200_000, makanModel, Fixtures.date(2025, 10, 31, 23, 30)),
            (300_000, makanModel, Fixtures.date(2025, 11, 1, 0, 30)),
            (8_000_000, gajiModel, Fixtures.date(2025, 6, 25)),
        ] as [(Int64, Subcategory, Date)] {
            store.context.insert(MoneyTransaction(amount: amount, subcategory: subcategory, date: date))
        }
        try store.context.save()
        let now = Fixtures.date(2026, 11, 20)
        let ledger = Ledger(context: store.context, timeZone: zone)
        let before = try ledger.yearRecap(for: 2025, now: now)

        let report = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(report.rolledUpMonths.count == 3)
        let after = try ledger.yearRecap(for: 2025, now: now)
        #expect(after == before)
        #expect(after.expenses == 600_000)
        #expect(after.income == 8_000_000)
        #expect(after.labels[makanModel.id] == SubcategoryLabel(name: "Makan", emoji: makanModel.emoji))
        #expect(try ledger.earliestMonthWithData() == MonthKey(year: 2025, month: 2))
    }
}
