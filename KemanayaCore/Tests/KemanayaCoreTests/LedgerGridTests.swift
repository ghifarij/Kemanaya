import Foundation
import KemanayaCore
import SwiftData
import Testing

/// The add sheet's subcategory grid (D-043).
struct LedgerGridTests {
    private func makeStore() throws -> (TestStore, Ledger) {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        return (store, Ledger(context: store.context, timeZone: Fixtures.jakarta))
    }

    @Test func expensesAreKebutuhanThenKeinginanInSeedOrder() throws {
        let (_, ledger) = try makeStore()
        let sections = try ledger.gridSections(for: .expense)
        #expect(sections.map(\.group) == [.kebutuhan, .keinginan])
        #expect(sections[0].subcategories.map(\.name) == SeedData.kebutuhan.map(\.name))
        #expect(sections[1].subcategories.map(\.name) == SeedData.keinginan.map(\.name))
        #expect(sections.map(\.id) == ["kebutuhan", "keinginan"])
    }

    @Test func incomeIsOneFlatSection() throws {
        let (_, ledger) = try makeStore()
        let sections = try ledger.gridSections(for: .income)
        #expect(sections.count == 1)
        #expect(sections[0].group == nil)
        #expect(sections[0].kind == .income)
        #expect(sections[0].subcategories.map(\.name) == SeedData.income.map(\.name))
    }

    @Test func followsSortOrderNotInsertionOrder() throws {
        let (store, ledger) = try makeStore()
        try store.subcategory(named: "Kopi").sortOrder = 99
        try store.subcategory(named: "Kado").sortOrder = -1
        try store.context.save()
        let keinginan = try ledger.gridSections(for: .expense)[1].subcategories.map(\.name)
        #expect(keinginan.first == "Kado")
        #expect(keinginan.last == "Kopi")
    }

    @Test func tiesInSortOrderBreakByName() throws {
        let (store, ledger) = try makeStore()
        store.context.insert(Subcategory(name: "Arisan", emoji: "🤝", kind: .income, group: nil, sortOrder: 0))
        try store.context.save()
        let income = try ledger.gridSections(for: .income)[0].subcategories.map(\.name)
        #expect(Array(income.prefix(2)) == ["Arisan", "Gaji"])
    }

    @Test func hiddenSubcategoriesAreLeftOut() throws {
        let (store, ledger) = try makeStore()
        try store.subcategory(named: "Galon").isHidden = true
        try store.subcategory(named: "Bonus").isHidden = true
        try store.context.save()
        #expect(!(try ledger.gridSections(for: .expense)[0].subcategories.map(\.name)).contains("Galon"))
        #expect(!(try ledger.gridSections(for: .income)[0].subcategories.map(\.name)).contains("Bonus"))
    }

    /// Editing a transaction whose subcategory was hidden still shows (and keeps) that subcategory.
    @Test func aHiddenSubcategoryCanBeIncludedOnRequest() throws {
        let (store, ledger) = try makeStore()
        let galon = try store.subcategory(named: "Galon")
        galon.isHidden = true
        try store.context.save()
        let names = try ledger.gridSections(for: .expense, including: galon.id)[0].subcategories.map(\.name)
        #expect(names == SeedData.kebutuhan.map(\.name))
        // An id of the other kind changes nothing.
        #expect(try ledger.gridSections(for: .income, including: galon.id)[0].subcategories.count == SeedData.income.count)
    }

    @Test func emptySectionsAreDropped() throws {
        let (store, ledger) = try makeStore()
        for subcategory in try store.subcategories() where subcategory.group == .keinginan {
            subcategory.isHidden = true
        }
        try store.context.save()
        #expect(try ledger.gridSections(for: .expense).map(\.group) == [.kebutuhan])
    }

    @Test func emptyStoreHasNoSections() throws {
        let store = try TestStore()
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        #expect(try ledger.gridSections(for: .expense).isEmpty)
        #expect(try ledger.gridSections(for: .income).isEmpty)
    }
}
