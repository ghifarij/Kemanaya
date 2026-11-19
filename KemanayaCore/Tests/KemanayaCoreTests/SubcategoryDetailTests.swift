import Foundation
import KemanayaCore
import Testing

/// The subcategory detail (D-041, D-051): month total, budget, last month, transactions.
struct SubcategoryDetailTests {
    private let kopi = UUID()
    private let makan = UUID()

    private func spend(_ amount: Int64, _ day: Int, month: Int = 11, id: UUID = UUID()) -> TransactionSnapshot {
        TransactionSnapshot(id: id, amount: amount, kind: .expense, group: .keinginan, subcategoryID: kopi, date: Fixtures.date(2026, month, day))
    }

    @Test func totalsComparisonAndTheSubcategorysTransactions() {
        let detail = SubcategoryDetail(
            subcategoryID: kopi,
            current: [
                spend(18_000, 3), spend(25_000, 17), spend(22_000, 9),
                TransactionSnapshot(amount: 50_000, kind: .expense, group: .kebutuhan, subcategoryID: makan, date: Fixtures.date(2026, 11, 4)),
            ],
            previous: [spend(40_000, 2, month: 10), spend(40_000, 20, month: 10)],
            monthlyBudget: nil
        )
        #expect(detail.total == 65_000)
        #expect(detail.previousTotal == 80_000)
        #expect(detail.difference == -15_000)
        #expect(detail.comparison.direction == .down)
        #expect(detail.count == 3, "Makan is left out")
        #expect(detail.transactions.map(\.amount) == [18_000, 25_000, 22_000], "input order: the screen's @Query sorts")
        #expect(detail.budget == nil, "no budget, no progress")
        #expect(!detail.isEmpty)
    }

    @Test func budgetProgressWhenSet() {
        let under = SubcategoryDetail(subcategoryID: kopi, current: [spend(120_000, 5)], previous: [TransactionSnapshot](), monthlyBudget: 300_000)
        #expect(under.budget == BudgetProgress(spent: 120_000, budget: 300_000))
        #expect(under.budget?.remaining == 180_000)
        let over = SubcategoryDetail(subcategoryID: kopi, current: [spend(360_000, 5)], previous: [TransactionSnapshot](), monthlyBudget: 300_000)
        #expect(over.budget?.isOverBudget == true)
        let zero = SubcategoryDetail(subcategoryID: kopi, current: [spend(1_000, 5)], previous: [TransactionSnapshot](), monthlyBudget: 0)
        #expect(zero.budget == nil, "a zero budget means none")
    }

    /// An empty month still shows last month and the budget, and nothing divides by zero.
    @Test func emptyMonth() {
        let detail = SubcategoryDetail(subcategoryID: kopi, current: [TransactionSnapshot](), previous: [spend(10_000, 1, month: 10)], monthlyBudget: 300_000)
        #expect(detail.isEmpty)
        #expect(detail.total == 0)
        #expect(detail.difference == -10_000)
        #expect(detail.budget?.spent == 0)
        #expect(detail.budget?.fraction == 0)
        let nothing = SubcategoryDetail(subcategoryID: kopi, current: [TransactionSnapshot](), previous: [TransactionSnapshot](), monthlyBudget: nil)
        #expect(nothing.comparison.direction == .same)
        #expect(nothing.comparison.currentFraction == 0)
        #expect(nothing.difference == 0)
    }
}
