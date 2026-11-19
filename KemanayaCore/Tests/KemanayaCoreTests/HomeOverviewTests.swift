import Foundation
@testable import KemanayaCore
import Testing

/// Home's numbers (D-009, D-012, D-041, D-048), built from plain snapshots.
struct HomeOverviewTests {
    private let makan = UUID()
    private let kopi = UUID()
    private let gaji = UUID()
    private let parkir = UUID()
    private let date = Fixtures.date(2026, 11, 18)

    private func expense(_ amount: Int64, _ id: UUID, _ group: ExpenseGroup) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .expense, group: group, subcategoryID: id, date: date)
    }

    private func income(_ amount: Int64, _ id: UUID) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .income, group: nil, subcategoryID: id, date: date)
    }

    @Test func cardsCompareThisMonthWithLastMonthInPinOrder() {
        let overview = HomeOverview(
            current: [expense(30_000, makan, .kebutuhan), expense(20_000, makan, .kebutuhan), expense(18_000, kopi, .keinginan), income(8_500_000, gaji)],
            previous: [expense(70_000, makan, .kebutuhan), income(8_000_000, gaji)],
            pins: [.init(id: kopi, monthlyBudget: nil), .init(id: makan, monthlyBudget: nil), .init(id: gaji, monthlyBudget: nil), .init(id: parkir, monthlyBudget: nil)],
            groupBudgets: [:]
        )
        #expect(overview.cards.map(\.id) == [kopi, makan, gaji, parkir])
        #expect(overview.card(for: kopi)?.comparison == MonthComparison(current: 18_000, previous: 0))
        #expect(overview.card(for: makan)?.comparison == MonthComparison(current: 50_000, previous: 70_000))
        #expect(overview.card(for: gaji)?.comparison == MonthComparison(current: 8_500_000, previous: 8_000_000), "income cards show income")
        #expect(overview.card(for: parkir)?.comparison == MonthComparison(current: 0, previous: 0))
        #expect(overview.card(for: UUID()) == nil)
    }

    @Test func monthTotalsComeFromTheCurrentMonthOnly() {
        let overview = HomeOverview(
            current: [expense(300_000, makan, .kebutuhan), expense(100_000, kopi, .keinginan), income(1_000_000, gaji)],
            previous: [expense(999_000, makan, .kebutuhan)],
            pins: [],
            groupBudgets: [:]
        )
        #expect(overview.month.expenses == 400_000)
        #expect(overview.month.sisa == 600_000)
        #expect(overview.month.savingsRatePercent == 60)
        #expect(!overview.isEmpty)
    }

    /// A fresh install: nothing logged, no budgets, so Home shows its empty state and no progress (D-048).
    @Test func freshInstallIsEmptyWithoutBudgets() {
        let overview = HomeOverview(current: [], previous: [], pins: [.init(id: makan, monthlyBudget: nil)], groupBudgets: [:])
        #expect(overview.isEmpty)
        #expect(overview.groupBudgets.isEmpty)
        #expect(overview.cards.first?.budget == nil)
    }

    /// Last month's spending alone doesn't fill this month.
    @Test func onlyLastMonthIsStillEmpty() {
        let overview = HomeOverview(current: [], previous: [expense(5_000, makan, .kebutuhan)], pins: [], groupBudgets: [:])
        #expect(overview.isEmpty)
    }

    @Test func groupBudgetsShowOnlyWhenSetInGroupOrder() {
        let current = [expense(1_200_000, makan, .kebutuhan), expense(600_000, kopi, .keinginan)]
        let onlyKeinginan = HomeOverview(current: current, previous: [], pins: [], groupBudgets: [.keinginan: 500_000])
        #expect(onlyKeinginan.groupBudgets.map(\.group) == [.keinginan])
        #expect(onlyKeinginan.groupBudgets.first?.progress.isOverBudget == true)
        #expect(onlyKeinginan.groupBudgets.first?.progress.remaining == -100_000)

        let both = HomeOverview(current: current, previous: [], pins: [], groupBudgets: [.keinginan: 500_000, .kebutuhan: 3_000_000])
        #expect(both.groupBudgets.map(\.group) == [.kebutuhan, .keinginan])
        #expect(both.groupBudgets.first?.progress == BudgetProgress(spent: 1_200_000, budget: 3_000_000))

        let zero = HomeOverview(current: current, previous: [], pins: [], groupBudgets: [.kebutuhan: 0])
        #expect(zero.groupBudgets.isEmpty, "a zero budget means no budget")
    }

    /// A budgeted card with nothing spent yet still shows progress; an unbudgeted one shows none.
    @Test func cardBudgetsOnlyWhereSet() {
        let overview = HomeOverview(
            current: [expense(45_000, kopi, .keinginan)],
            previous: [],
            pins: [.init(id: kopi, monthlyBudget: 300_000), .init(id: parkir, monthlyBudget: 50_000), .init(id: makan, monthlyBudget: nil)],
            groupBudgets: [:]
        )
        #expect(overview.card(for: kopi)?.budget == BudgetProgress(spent: 45_000, budget: 300_000))
        #expect(overview.card(for: parkir)?.budget == BudgetProgress(spent: 0, budget: 50_000))
        #expect(overview.card(for: makan)?.budget == nil)
    }
}
