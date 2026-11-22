import Foundation
@testable import KemanayaCore
import Testing

/// The Analisis income line (D-070): spending with income as context, never a difference or a rate.
struct IncomeLineTests {
    private let makan = UUID()
    private let kopi = UUID()
    private let gaji = UUID()
    private let date = Fixtures.date(2026, 11, 18)

    private func expense(_ amount: Int64, _ id: UUID, _ group: ExpenseGroup) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .expense, group: group, subcategoryID: id, date: date)
    }

    private func income(_ amount: Int64) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .income, group: nil, subcategoryID: gaji, date: date)
    }

    @Test func spendingOfIncomeCountsBothGroups() {
        let summary = MonthSummary([expense(4_000_000, makan, .kebutuhan), expense(250_000, kopi, .keinginan), income(8_500_000)])
        #expect(IncomeLine(summary) == .spentOfIncome(spent: 4_250_000, income: 8_500_000))
    }

    /// Spending past income is just two numbers: no note, no sign (D-022).
    @Test func spendingPastIncomeIsStillTheSamePair() {
        let summary = MonthSummary([expense(9_000_000, makan, .kebutuhan), income(8_500_000)])
        #expect(IncomeLine(summary) == .spentOfIncome(spent: 9_000_000, income: 8_500_000))
    }

    @Test func noIncomeYet() {
        let summary = MonthSummary([expense(4_250_000, makan, .kebutuhan)])
        #expect(IncomeLine(summary) == .noIncome(spent: 4_250_000))
    }

    @Test func incomeWithoutSpendingStillShowsTheLine() {
        #expect(IncomeLine(MonthSummary([income(8_500_000)])) == .spentOfIncome(spent: 0, income: 8_500_000))
    }

    /// Nothing at all: the line is hidden; the page's empty state covers the month.
    @Test func emptyMonthHasNoLine() {
        #expect(IncomeLine(MonthSummary([])) == nil)
    }

    /// Rollups count too, as everywhere else on Analisis (D-055).
    @Test func readsRollups() {
        let month = MonthKey(year: 2025, month: 11)
        let summary = MonthSummary([], rollups: [
            RollupSnapshot(month: month, subcategoryID: makan, kind: .expense, group: .kebutuhan, total: 1_000_000, count: 3),
            RollupSnapshot(month: month, subcategoryID: gaji, kind: .income, group: nil, total: 8_000_000, count: 1),
        ])
        #expect(IncomeLine(summary) == .spentOfIncome(spent: 1_000_000, income: 8_000_000))
    }
}
