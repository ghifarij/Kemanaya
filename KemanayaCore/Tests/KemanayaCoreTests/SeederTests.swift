import Foundation
import KemanayaCore
import SwiftData
import Testing

struct SeederTests {
    @Test func seedsEverySubcategoryOnAnEmptyStore() throws {
        let store = try TestStore()
        #expect(try Seeder.seedIfNeeded(in: store.context))

        let all = try store.subcategories()
        #expect(all.count == 44)
        #expect(all.filter { $0.kind == .income }.count == 8)
        #expect(all.filter { $0.group == .kebutuhan }.count == 22)
        #expect(all.filter { $0.group == .keinginan }.count == 14)
        #expect(all.allSatisfy { !$0.isHidden && $0.monthlyBudget == nil })
        // Seeded rows take the fixed seed ids, so a restore can match them (D-019).
        let seedIDs = SeedData.sections.flatMap { $0 }.map(\.id)
        #expect(Set(all.map(\.id)) == Set(seedIDs))
        #expect(try store.subcategory(named: "Gaji").id == UUID(uuidString: "E84A09B0-1D55-478F-9C05-3F03FBF6AD12"))

        let settings = try AppSettings.fetchOrCreate(in: store.context)
        #expect(settings.seedVersion == SeedData.version)
        #expect(settings.budget(for: .kebutuhan) == nil)
        #expect(settings.budget(for: .keinginan) == nil)
    }

    @Test func sortOrderFollowsTheSpecWithinEachSection() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let kebutuhan = try store.subcategories()
            .filter { $0.group == .kebutuhan }
            .sorted { $0.sortOrder < $1.sortOrder }
        #expect(kebutuhan.map(\.name) == SeedData.kebutuhan.map(\.name))
        #expect(kebutuhan.map(\.sortOrder) == Array(0..<22))
    }

    @Test func pinsTheDefaultSixInOrder() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let pinned = try Ledger(context: store.context, timeZone: Fixtures.jakarta).pinnedSubcategories()
        #expect(pinned.map(\.name) == ["Makan", "Kopi", "Jajan", "Parkir", "Galon", "Hiburan"])
        #expect(pinned.map(\.pinOrder) == [0, 1, 2, 3, 4, 5])
        #expect(try store.subcategories().filter(\.isPinned).count == 6)
    }

    @Test func runningTwiceChangesNothing() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let before = try store.subcategories().map { [$0.id.uuidString, $0.name, $0.emoji, "\($0.pinOrder ?? -1)"] }

        #expect(try !Seeder.seedIfNeeded(in: store.context))

        let after = try store.subcategories().map { [$0.id.uuidString, $0.name, $0.emoji, "\($0.pinOrder ?? -1)"] }
        #expect(after == before)
        #expect(try store.context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }

    @Test func neverRenamesUnhidesOrResurrectsUserEdits() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)

        try store.subcategory(named: "Kopi").name = "Ngopi"
        try store.subcategory(named: "Jajan").isHidden = true
        try store.subcategory(named: "Makan").pinOrder = nil
        store.context.delete(try store.subcategory(named: "Kado"))
        try store.context.save()

        try Seeder.seedIfNeeded(in: store.context)

        let names = try store.subcategories().map(\.name)
        #expect(names.count == 43)
        #expect(!names.contains("Kopi"))
        #expect(names.contains("Ngopi"))
        #expect(!names.contains("Kado"))
        #expect(try store.subcategory(named: "Jajan").isHidden)
        #expect(try store.subcategory(named: "Makan").pinOrder == nil)
    }

    /// A store that already has subcategories (e.g. a future restore) but no seed record is left alone.
    @Test func doesNotSeedOverExistingSubcategories() throws {
        let store = try TestStore()
        store.context.insert(Subcategory(name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan, sortOrder: 0))
        try store.context.save()

        #expect(try !Seeder.seedIfNeeded(in: store.context))
        #expect(try store.subcategories().count == 1)
        #expect(try AppSettings.fetchOrCreate(in: store.context).seedVersion == SeedData.version)
    }
}
