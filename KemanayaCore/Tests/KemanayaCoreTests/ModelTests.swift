import Foundation
import KemanayaCore
import SwiftData
import Testing

struct ModelTests {
    @Test func transactionCopiesItsSubcategorysKindAndGroup() throws {
        let store = try TestStore()
        let kopi = Subcategory(name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan, sortOrder: 0)
        let gaji = Subcategory(name: "Gaji", emoji: "💼", kind: .income, group: nil, sortOrder: 0)
        store.context.insert(kopi)
        store.context.insert(gaji)
        let transaction = MoneyTransaction(amount: 25_000, subcategory: kopi, date: Fixtures.date(2026, 11, 3))
        store.context.insert(transaction)
        try store.context.save()

        #expect(transaction.kind == .expense)
        #expect(transaction.group == .keinginan)
        #expect(TransactionSnapshot(transaction).id == transaction.id)
        #expect(transaction.subcategoryID == kopi.id)
        #expect(kopi.transactions.count == 1)

        transaction.move(to: gaji)
        try store.context.save()
        #expect(transaction.kind == .income)
        #expect(transaction.group == nil)
        #expect(transaction.subcategoryID == gaji.id)
        #expect(kopi.transactions.isEmpty)
        #expect(gaji.transactions.count == 1)
    }

    @Test func blankNotesAreStoredAsNil() throws {
        let kopi = Subcategory(name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan, sortOrder: 0)
        let transaction = MoneyTransaction(amount: 25_000, subcategory: kopi, note: "  \n")
        #expect(transaction.note == nil)
        transaction.setNote("Kopi susu")
        #expect(transaction.note == "Kopi susu")
        transaction.setNote("")
        #expect(transaction.note == nil)
    }

    @Test func deletingASubcategoryKeepsItsTransactionsCountable() throws {
        let store = try TestStore()
        let kopi = Subcategory(name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan, sortOrder: 0)
        store.context.insert(kopi)
        store.context.insert(MoneyTransaction(amount: 25_000, subcategory: kopi, date: Fixtures.date(2026, 11, 3)))
        try store.context.save()

        store.context.delete(kopi)
        try store.context.save()

        let remaining = try store.context.fetch(FetchDescriptor<MoneyTransaction>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.subcategory == nil)
        #expect(remaining.first?.group == .keinginan)
    }

    @Test func subcategoryBudgetsAreForExpensesOnly() throws {
        let kopi = Subcategory(name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan, sortOrder: 0)
        try kopi.setMonthlyBudget(300_000)
        #expect(kopi.monthlyBudget == 300_000)
        try kopi.setMonthlyBudget(0)
        #expect(kopi.monthlyBudget == nil)
        try kopi.setMonthlyBudget(150_000)
        try kopi.setMonthlyBudget(nil)
        #expect(kopi.monthlyBudget == nil)

        let gaji = Subcategory(name: "Gaji", emoji: "💼", kind: .income, group: nil, sortOrder: 0)
        #expect(throws: BudgetError.incomeHasNoBudget) { try gaji.setMonthlyBudget(1_000_000) }
        #expect(gaji.monthlyBudget == nil)
        // Clearing is always allowed.
        try gaji.setMonthlyBudget(nil)
    }

    @Test func groupBudgetsAreOptionalAndPositive() throws {
        let store = try TestStore()
        let settings = try AppSettings.fetchOrCreate(in: store.context)
        settings.setBudget(2_000_000, for: .kebutuhan)
        settings.setBudget(-1, for: .keinginan)
        try store.context.save()

        let reloaded = try AppSettings.fetchOrCreate(in: ModelContext(store.container))
        #expect(reloaded.budget(for: .kebutuhan) == 2_000_000)
        #expect(reloaded.budget(for: .keinginan) == nil)
        #expect(try store.context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }

    /// `#Unique` on (month, subcategory): a second insert updates the row instead of adding one.
    @Test func rollupsAreUniquePerMonthAndSubcategory() throws {
        let store = try TestStore()
        let id = UUID()
        let november = MonthKey(year: 2026, month: 11)
        store.context.insert(MonthlyRollup(month: november, subcategoryID: id, total: 100, count: 1, name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan))
        try store.context.save()
        store.context.insert(MonthlyRollup(month: november, subcategoryID: id, total: 300, count: 3, name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan))
        store.context.insert(MonthlyRollup(month: november.next, subcategoryID: id, total: 50, count: 1, name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan))
        try store.context.save()

        let rollups = try ModelContext(store.container).fetch(FetchDescriptor<MonthlyRollup>(sortBy: [SortDescriptor(\.monthKey)]))
        #expect(rollups.count == 2)
        #expect(rollups.first?.total == 300)
        #expect(rollups.first?.month == november)
        #expect(rollups.first?.group == .keinginan)
    }

    /// Two transactions never share an id; an explicit id (restore, D-019) is kept.
    @Test func transactionsHaveStableUniqueIDs() throws {
        let kopi = Subcategory(name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan, sortOrder: 0)
        let restoredID = UUID()
        let restored = MoneyTransaction(id: restoredID, amount: 1, subcategory: kopi)
        let fresh = MoneyTransaction(amount: 1, subcategory: kopi)
        #expect(restored.id == restoredID)
        #expect(fresh.id != restoredID)
    }
}
