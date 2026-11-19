import Foundation
import KemanayaCore
import Testing

struct ExpenseFilterTests {
    private func snapshot(_ kind: TransactionKind, _ group: ExpenseGroup?) -> TransactionSnapshot {
        TransactionSnapshot(amount: 1_000, kind: kind, group: group, subcategoryID: UUID(), date: .now)
    }

    @Test func keepsOnlyExpensesOfItsGroups() {
        #expect(ExpenseFilter.all.includes(snapshot(.expense, .kebutuhan)))
        #expect(ExpenseFilter.all.includes(snapshot(.expense, .keinginan)))
        #expect(!ExpenseFilter.all.includes(snapshot(.income, nil)), "income is never analysed as spending")
        #expect(!ExpenseFilter.all.includes(snapshot(.expense, nil)), "an expense without a group is skipped")
        #expect(ExpenseFilter.kebutuhan.includes(snapshot(.expense, .kebutuhan)))
        #expect(!ExpenseFilter.kebutuhan.includes(snapshot(.expense, .keinginan)))
        #expect(ExpenseFilter.keinginan.includes(snapshot(.expense, .keinginan)))
        #expect(!ExpenseFilter.keinginan.includes(snapshot(.expense, .kebutuhan)))
    }

    @Test func groupsInDisplayOrder() {
        #expect(ExpenseFilter.all.groups == [.kebutuhan, .keinginan])
        #expect(ExpenseFilter.kebutuhan.groups == [.kebutuhan])
        #expect(ExpenseFilter.keinginan.groups == [.keinginan])
        #expect(ExpenseFilter.allCases == [.all, .kebutuhan, .keinginan], "Semua · Kebutuhan · Keinginan")
    }
}
