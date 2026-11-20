import Foundation
import KemanayaCore
import Testing

struct MonthSummaryTests {
    private let makan = UUID()
    private let kopi = UUID()
    private let jajan = UUID()
    private let gaji = UUID()

    private func expense(_ amount: Int64, _ id: UUID, _ group: ExpenseGroup) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .expense, group: group, subcategoryID: id, date: Fixtures.date(2026, 11, 10))
    }

    private func income(_ amount: Int64, _ id: UUID) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .income, group: nil, subcategoryID: id, date: Fixtures.date(2026, 11, 1))
    }

    private var sample: MonthSummary {
        MonthSummary([
            income(10_000_000, gaji),
            expense(50_000, makan, .kebutuhan),
            expense(25_000, makan, .kebutuhan),
            expense(30_000, kopi, .keinginan),
            expense(30_000, kopi, .keinginan),
            expense(15_000, jajan, .keinginan),
        ])
    }

    /// 13 months of maximum-size entries fit with room to spare; past `Int64`'s limit sums clamp
    /// instead of trapping (D-016).
    @Test func sumsNeverOverflow() {
        // A month with a thousand maximum-size entries a day, for 13 months, per group and income.
        let perMonth = AmountEntry.maximum * 31_000
        let rollups = (1...13).flatMap { offset in
            let month = MonthKey(year: 2025, month: 11).adding(months: offset - 1)
            return [
                RollupSnapshot(month: month, subcategoryID: makan, kind: .expense, group: .kebutuhan, total: perMonth, count: 31_000),
                RollupSnapshot(month: month, subcategoryID: kopi, kind: .expense, group: .keinginan, total: perMonth, count: 31_000),
                RollupSnapshot(month: month, subcategoryID: gaji, kind: .income, group: nil, total: perMonth, count: 31_000),
            ]
        }
        let fits = MonthSummary([], rollups: rollups)
        #expect(fits.kebutuhan == perMonth * 13)
        #expect(fits.expenses == perMonth * 26)
        #expect(fits.sisa == -perMonth * 13)

        let huge = MonthSummary([], rollups: [
            RollupSnapshot(month: MonthKey(year: 2025, month: 1), subcategoryID: makan, kind: .expense, group: .kebutuhan, total: .max, count: 1),
            RollupSnapshot(month: MonthKey(year: 2025, month: 2), subcategoryID: makan, kind: .expense, group: .kebutuhan, total: .max, count: 1),
            RollupSnapshot(month: MonthKey(year: 2025, month: 1), subcategoryID: kopi, kind: .expense, group: .keinginan, total: .max, count: 1),
        ])
        #expect(huge.kebutuhan == .max)
        #expect(huge.total(for: makan) == .max)
        #expect(huge.expenses == .max)
        #expect(huge.sisa == -.max)
        #expect(Breakdown(summary: huge).total == .max)
    }

    @Test func totalsPerGroupAndIncome() {
        let summary = sample
        #expect(summary.kebutuhan == 75_000)
        #expect(summary.keinginan == 75_000)
        #expect(summary.expenses == 150_000)
        #expect(summary.income == 10_000_000)
        #expect(summary.spent(on: .kebutuhan) == 75_000)
        #expect(summary.spent(on: .keinginan) == 75_000)
    }

    @Test func totalsPerSubcategoryAreRankedLargestFirst() {
        let summary = sample
        #expect(summary.subcategories.map(\.subcategoryID).first == gaji)
        #expect(summary.total(for: makan) == 75_000)
        #expect(summary.total(for: kopi) == 60_000)
        #expect(summary.total(for: jajan) == 15_000)
        #expect(summary.total(for: UUID()) == 0)

        let makanTotal = summary.subcategories.first { $0.subcategoryID == makan }
        #expect(makanTotal == SubcategoryTotal(subcategoryID: makan, kind: .expense, group: .kebutuhan, total: 75_000, count: 2))
        let totals = summary.subcategories.map(\.total)
        #expect(totals == totals.sorted(by: >))
    }

    @Test func equalTotalsRankByCountThenStably() {
        let a = UUID()
        let b = UUID()
        let summary = MonthSummary([
            expense(10_000, a, .keinginan),
            expense(5_000, b, .keinginan),
            expense(5_000, b, .keinginan),
        ])
        #expect(summary.subcategories.map(\.subcategoryID) == [b, a])

        // Full ties don't depend on input order.
        let forward = MonthSummary([expense(1, a, .keinginan), expense(1, b, .keinginan)])
        let backward = MonthSummary([expense(1, b, .keinginan), expense(1, a, .keinginan)])
        #expect(forward.subcategories == backward.subcategories)
    }

    @Test func sisaAndSavingsRate() {
        let summary = sample
        #expect(summary.sisa == 9_850_000)
        #expect(summary.savingsRate == 0.985)
        #expect(summary.savingsRatePercent == 99)
    }

    @Test func overspendingGivesNegativeSisaAndRate() {
        let summary = MonthSummary([income(1_000_000, gaji), expense(1_250_000, makan, .kebutuhan)])
        #expect(summary.sisa == -250_000)
        #expect(summary.savingsRate == -0.25)
        #expect(summary.savingsRatePercent == -25)
    }

    /// The neutral "Pengeluaran melebihi pemasukan" note shows only when there is a rate and it is negative (D-050).
    @Test func savingsRateIsNegativeOnlyWhenSpendingPassesIncome() {
        #expect(MonthSummary([income(1_000_000, gaji), expense(1_250_000, makan, .kebutuhan)]).isSavingsRateNegative)
        #expect(MonthSummary([income(1_000_000, gaji), expense(1_000_001, makan, .kebutuhan)]).isSavingsRateNegative, "even when it rounds to 0 %")
        #expect(!MonthSummary([income(1_000_000, gaji), expense(1_000_000, makan, .kebutuhan)]).isSavingsRateNegative, "breaking even is not negative")
        #expect(!sample.isSavingsRateNegative)
        #expect(!MonthSummary([expense(50_000, makan, .kebutuhan)]).isSavingsRateNegative, "no income, no rate")
        #expect(!MonthSummary([]).isSavingsRateNegative)
    }

    @Test func noIncomeMeansNoSavingsRate() {
        let summary = MonthSummary([expense(50_000, makan, .kebutuhan)])
        #expect(summary.sisa == -50_000)
        #expect(summary.savingsRate == nil)
        #expect(summary.savingsRatePercent == nil)
    }

    @Test func emptyMonth() {
        let summary = MonthSummary([])
        #expect(summary.expenses == 0)
        #expect(summary.income == 0)
        #expect(summary.sisa == 0)
        #expect(summary.savingsRate == nil)
        #expect(summary.subcategories.isEmpty)
    }

    @Test func savingsPercentRoundsHalfAwayFromZero() {
        // 1/8 = 12.5 % → 13 %.
        let summary = MonthSummary([income(800, gaji), expense(700, makan, .kebutuhan)])
        #expect(summary.savingsRatePercent == 13)
    }

    /// 14.5 % is an exact half; `Double` sees 14.4999… and would give 14.
    @Test func exactHalfPercentRoundsAwayFromZero() {
        let saving = MonthSummary([income(1_000_000, gaji), expense(855_000, makan, .kebutuhan)])
        #expect(saving.sisa == 145_000)
        #expect(saving.savingsRatePercent == 15)

        let overspending = MonthSummary([income(1_000_000, gaji), expense(1_145_000, makan, .kebutuhan)])
        #expect(overspending.sisa == -145_000)
        #expect(overspending.savingsRatePercent == -15)
    }

    @Test func percentRoundsToNearestOtherwise() {
        #expect(MonthSummary([income(1_000_000, gaji), expense(855_001, makan, .kebutuhan)]).savingsRatePercent == 14)
        #expect(MonthSummary([income(3, gaji), expense(2, makan, .kebutuhan)]).savingsRatePercent == 33)
        #expect(MonthSummary([income(3, gaji), expense(1, makan, .kebutuhan)]).savingsRatePercent == 67)
        #expect(MonthSummary([income(1_000, gaji), expense(1_000, makan, .kebutuhan)]).savingsRatePercent == 0)
    }

    @Test func absurdAmountsFallBackInsteadOfTrapping() {
        let summary = MonthSummary([income(.max / 2, gaji)])
        #expect(summary.savingsRatePercent == 100)
    }

    /// An expense without a group is invalid data (D-003): it's left out of every total.
    @Test func expenseWithoutGroupIsSkippedEverywhere() {
        let orphan = UUID()
        let summary = MonthSummary([
            TransactionSnapshot(amount: 9_999, kind: .expense, group: nil, subcategoryID: orphan, date: .now),
            expense(10_000, makan, .kebutuhan),
        ])
        #expect(summary.expenses == 10_000)
        #expect(summary.total(for: orphan) == 0)
        #expect(summary.subcategories.map(\.subcategoryID) == [makan])
    }

    @Test func expenseSubcategoriesLeaveOutIncome() {
        #expect(sample.subcategories.contains { $0.kind == .income })
        #expect(sample.expenseSubcategories.map(\.subcategoryID) == [makan, kopi, jajan])
    }

    @Test func realisticLargeAmountsDoNotOverflow() {
        // A year of daily Rp1 billion entries is still far from Int64's limit.
        let summary = MonthSummary(Array(repeating: expense(1_000_000_000, makan, .kebutuhan), count: 366))
        #expect(summary.kebutuhan == 366_000_000_000)
    }
}

struct BudgetProgressTests {
    @Test func underBudget() throws {
        let progress = try #require(BudgetProgress(spent: 750_000, budget: 1_000_000))
        #expect(progress.remaining == 250_000)
        #expect(progress.fraction == 0.75)
        #expect(progress.clampedFraction == 0.75)
        #expect(!progress.isOverBudget)
    }

    @Test func exactlyOnBudgetIsNotOver() throws {
        let progress = try #require(BudgetProgress(spent: 1_000_000, budget: 1_000_000))
        #expect(progress.remaining == 0)
        #expect(!progress.isOverBudget)
    }

    @Test func overBudget() throws {
        let progress = try #require(BudgetProgress(spent: 1_250_000, budget: 1_000_000))
        #expect(progress.remaining == -250_000)
        #expect(progress.fraction == 1.25)
        #expect(progress.clampedFraction == 1)
        #expect(progress.isOverBudget)
    }

    @Test func zeroOrNegativeBudgetMeansNoBudget() {
        #expect(BudgetProgress(spent: 10, budget: 0) == nil)
        #expect(BudgetProgress(spent: 10, budget: -5) == nil)
    }

    @Test func groupProgressFromSummary() throws {
        let summary = MonthSummary([
            TransactionSnapshot(amount: 400_000, kind: .expense, group: .keinginan, subcategoryID: UUID(), date: .now),
        ])
        #expect(summary.budgetProgress(for: .keinginan, budget: nil) == nil)
        let keinginan = try #require(summary.budgetProgress(for: .keinginan, budget: 500_000))
        #expect(keinginan.spent == 400_000)
        let kebutuhan = try #require(summary.budgetProgress(for: .kebutuhan, budget: 2_000_000))
        #expect(kebutuhan.spent == 0)
    }

    @Test func subcategoryProgressFromSummary() throws {
        let kopi = UUID()
        let delivery = UUID()
        let summary = MonthSummary([
            TransactionSnapshot(amount: 180_000, kind: .expense, group: .keinginan, subcategoryID: kopi, date: .now),
            TransactionSnapshot(amount: 5_000_000, kind: .income, group: nil, subcategoryID: UUID(), date: .now),
        ])

        #expect(summary.budgetProgress(forSubcategory: kopi, budget: nil) == nil)
        let kopiProgress = try #require(summary.budgetProgress(forSubcategory: kopi, budget: 150_000))
        #expect(kopiProgress.spent == 180_000)
        #expect(kopiProgress.isOverBudget)

        // Budgeted but nothing spent yet: progress at zero.
        #expect(summary.budgetProgress(forSubcategory: delivery, budget: 200_000)?.spent == 0)

        // Income can't hold a budget (the model throws, the Ledger filters), so it never reaches here.
        let all = summary.subcategoryBudgetProgress([kopi: 150_000, delivery: 200_000])
        #expect(Set(all.keys) == [kopi, delivery])
        #expect(all[kopi]?.remaining == -30_000)
    }
}
