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
        #expect(overview.month.income == 1_000_000)
        #expect(!overview.isEmpty)
    }

    /// A fresh install: nothing logged, no budgets, so Home shows its empty state and no progress (D-048).
    @Test func freshInstallIsEmptyWithoutBudgets() {
        let overview = HomeOverview(current: [], previous: [], pins: [.init(id: makan, monthlyBudget: nil)], groupBudgets: [:])
        #expect(overview.isEmpty)
        #expect(overview.groups.allSatisfy { $0.budget == nil })
        #expect(overview.cards.first?.budget == nil)
    }

    /// Last month's spending alone doesn't fill this month.
    @Test func onlyLastMonthIsStillEmpty() {
        let overview = HomeOverview(current: [], previous: [expense(5_000, makan, .kebutuhan)], pins: [], groupBudgets: [:])
        #expect(overview.isEmpty)
    }

    /// The hero has an entry for each group, in group order, budgeted or not (D-068, D-073).
    @Test func groupRowsShowBudgetsOnlyWhenSetInGroupOrder() {
        let current = [expense(1_200_000, makan, .kebutuhan), expense(600_000, kopi, .keinginan)]
        let onlyKeinginan = HomeOverview(current: current, previous: [], pins: [], groupBudgets: [.keinginan: 500_000])
        #expect(onlyKeinginan.groups.map(\.group) == [.kebutuhan, .keinginan])
        #expect(onlyKeinginan.groups[0].budget == nil)
        #expect(onlyKeinginan.groups[1].budget?.isOverBudget == true)
        #expect(onlyKeinginan.groups[1].budget?.remaining == -100_000)

        let both = HomeOverview(current: current, previous: [], pins: [], groupBudgets: [.keinginan: 500_000, .kebutuhan: 3_000_000])
        #expect(both.groups[0].budget == BudgetProgress(spent: 1_200_000, budget: 3_000_000))

        let zero = HomeOverview(current: current, previous: [], pins: [], groupBudgets: [.kebutuhan: 0])
        #expect(zero.groups.allSatisfy { $0.budget == nil }, "a zero budget means no budget")
    }

    /// Each group's share of the month's spending, for the hero's split bar (D-073); the shares add up to 100.
    @Test func groupRowsShowTheShareOfSpending() {
        let overview = HomeOverview(
            current: [expense(730_000, makan, .kebutuhan), expense(270_000, kopi, .keinginan), income(9_000_000, gaji)],
            previous: [],
            pins: [],
            groupBudgets: [:]
        )
        #expect(overview.groups.map(\.spent) == [730_000, 270_000], "income isn't spending")
        #expect(overview.groups.map(\.sharePercent) == [73, 27])

        let incomeOnly = HomeOverview(current: [income(9_000_000, gaji)], previous: [], pins: [], groupBudgets: [:])
        #expect(incomeOnly.groups.map(\.sharePercent) == [0, 0])
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
