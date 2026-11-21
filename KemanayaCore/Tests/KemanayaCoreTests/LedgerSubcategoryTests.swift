import Foundation
@testable import KemanayaCore
import SwiftData
import Testing

/// Pengaturan's subcategory and budget writes through ``Ledger`` (D-006, D-007, D-041, D-049, D-062).
struct LedgerSubcategoryTests {
    private let now = Fixtures.date(2026, 11, 15)

    private func makeStore() throws -> (TestStore, Ledger) {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        return (store, Ledger(context: store.context, timeZone: Fixtures.jakarta))
    }

    /// A ledger over a fresh context: what is saved, not what is pending.
    private func saved(_ store: TestStore) -> Ledger {
        Ledger(context: ModelContext(store.container), timeZone: Fixtures.jakarta)
    }

    /// Visible names of one grid section, as the add sheet shows them.
    private func gridNames(_ ledger: Ledger, kind: TransactionKind, group: ExpenseGroup?) throws -> [String] {
        try ledger.gridSections(for: kind).first { $0.group == group }?.subcategories.map(\.name) ?? []
    }

    private func savedSubcategory(_ store: TestStore, named name: String) throws -> Subcategory? {
        try ModelContext(store.container).fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == name })).first
    }

    private func log(_ ledger: Ledger, _ amount: Int64, into subcategory: Subcategory) throws {
        try ledger.addTransaction(amount: amount, subcategory: subcategory, date: now, note: nil, now: now)
    }

    // MARK: - Add

    @Test func addAppendsToTheEndOfItsSection() throws {
        let (store, ledger) = try makeStore()
        let bakso = try ledger.addSubcategory(name: "  Bakso ", emoji: " 🍜 ", kind: .expense, group: .keinginan, now: now)
        #expect(!store.context.hasChanges, "add saves")
        #expect(bakso.name == "Bakso", "the name is trimmed")
        #expect(bakso.emoji == "🍜", "the emoji is trimmed")
        #expect(bakso.kind == .expense && bakso.group == .keinginan)
        #expect(!bakso.isHidden && !bakso.isPinned && bakso.monthlyBudget == nil)
        #expect(bakso.sortOrder == SeedData.keinginan.count)
        #expect(try gridNames(saved(store), kind: .expense, group: .keinginan) == SeedData.keinginan.map(\.name) + ["Bakso"])
        #expect(try gridNames(saved(store), kind: .expense, group: .kebutuhan) == SeedData.kebutuhan.map(\.name), "the other group is untouched")
    }

    @Test func addIncomeHasNoGroup() throws {
        let (store, ledger) = try makeStore()
        let thr = try ledger.addSubcategory(name: "Dividen", emoji: "💹", kind: .income, group: nil, now: now)
        #expect(thr.group == nil)
        #expect(try gridNames(saved(store), kind: .income, group: nil) == SeedData.income.map(\.name) + ["Dividen"])
    }

    /// A hidden subcategory keeps its place, so a new one goes after it too.
    @Test func addGoesAfterHiddenOnes() throws {
        let (_, ledger) = try makeStore()
        let all = try ledger.subcategories(of: .expense).filter { $0.group == .keinginan }
        try ledger.hide(try #require(all.last))
        let bakso = try ledger.addSubcategory(name: "Bakso", emoji: "🍜", kind: .expense, group: .keinginan, now: now)
        #expect(bakso.sortOrder == all.count)
    }

    @Test func addWithABudgetStoresIt() throws {
        let (store, ledger) = try makeStore()
        try ledger.addSubcategory(name: "Bakso", emoji: "🍜", kind: .expense, group: .keinginan, monthlyBudget: 200_000, now: now)
        #expect(try savedSubcategory(store, named: "Bakso")?.monthlyBudget == 200_000)
    }

    @Test func addWithAZeroBudgetHasNone() throws {
        let (store, ledger) = try makeStore()
        try ledger.addSubcategory(name: "Bakso", emoji: "🍜", kind: .expense, group: .keinginan, monthlyBudget: 0, now: now)
        #expect(try savedSubcategory(store, named: "Bakso")?.monthlyBudget == nil)
    }

    @Test(arguments: [
        ("", SubcategoryNameProblem.empty),
        ("   ", .empty),
        ("Kopi susu", .notOneWord),
        ("Kopi\tsusu", .notOneWord),
        ("Transportasi", .tooLong),
        ("Kopi", .taken),
        ("kopi", .taken),
        ("KOPI", .taken),
        ("Kópi", .taken),
        (" kopi ", .taken),
        ("hadiah", .taken), // an income name counts for an expense too (D-062)
    ])
    func addRefusesABadName(name: String, problem: SubcategoryNameProblem) throws {
        let (store, ledger) = try makeStore()
        #expect(throws: SubcategoryError.invalidName(problem)) {
            try ledger.addSubcategory(name: name, emoji: "🍜", kind: .expense, group: .keinginan, now: now)
        }
        #expect(!store.context.hasChanges)
        #expect(try store.subcategories().count == 44)
    }

    @Test func aTenCharacterNameFits() throws {
        let (_, ledger) = try makeStore()
        let name = String(repeating: "a", count: SubcategoryRules.maximumNameLength)
        #expect(try ledger.addSubcategory(name: name, emoji: "🍜", kind: .expense, group: .kebutuhan, now: now).name == name)
    }

    /// A hidden subcategory's name is still taken, so unhiding it can never make two "Kado" (D-062).
    @Test func aHiddenNameIsTaken() throws {
        let (_, ledger) = try makeStore()
        let all = try ledger.subcategories(of: .expense)
        try ledger.hide(try #require(all.first { $0.name == "Kado" }))
        #expect(throws: SubcategoryError.invalidName(.taken)) {
            try ledger.addSubcategory(name: "kado", emoji: "🎁", kind: .expense, group: .keinginan, now: now)
        }
    }

    @Test(arguments: ["", "a", "☕☕", "1", "#"])
    func addRefusesABadEmoji(emoji: String) throws {
        let (store, ledger) = try makeStore()
        #expect(throws: SubcategoryError.invalidEmoji) {
            try ledger.addSubcategory(name: "Bakso", emoji: emoji, kind: .expense, group: .keinginan, now: now)
        }
        #expect(!store.context.hasChanges)
    }

    @Test func addRefusesABadPlacement() throws {
        let (store, ledger) = try makeStore()
        #expect(throws: SubcategoryError.invalidPlacement) {
            try ledger.addSubcategory(name: "Bakso", emoji: "🍜", kind: .expense, group: nil, now: now)
        }
        #expect(throws: SubcategoryError.invalidPlacement) {
            try ledger.addSubcategory(name: "Dividen", emoji: "💹", kind: .income, group: .kebutuhan, now: now)
        }
        #expect(!store.context.hasChanges)
    }

    @Test func addRefusesABadBudget() throws {
        let (store, ledger) = try makeStore()
        #expect(throws: BudgetError.overMaximum) {
            try ledger.addSubcategory(name: "Bakso", emoji: "🍜", kind: .expense, group: .keinginan, monthlyBudget: AmountEntry.maximum + 1, now: now)
        }
        #expect(throws: BudgetError.incomeHasNoBudget) {
            try ledger.addSubcategory(name: "Dividen", emoji: "💹", kind: .income, group: nil, monthlyBudget: 100_000, now: now)
        }
        #expect(!store.context.hasChanges)
        #expect(try store.subcategories().count == 44)
        try ledger.addSubcategory(name: "Bakso", emoji: "🍜", kind: .expense, group: .keinginan, monthlyBudget: AmountEntry.maximum, now: now)
    }

    // MARK: - Update

    /// Transactions follow the subcategory; rollups keep their snapshot (D-059, D-062).
    @Test func renameCarriesTransactionsButNotRollupSnapshots() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try log(ledger, 18_000, into: kopi)
        store.context.insert(MonthlyRollup(
            month: MonthKey(year: 2025, month: 1), subcategoryID: kopi.id, total: 50_000, count: 2,
            name: "Kopi", emoji: "☕", kind: .expense, group: .keinginan
        ))
        try store.context.save()

        try ledger.updateSubcategory(kopi, name: "Ngopi", emoji: "🫖", monthlyBudget: nil)
        #expect(!store.context.hasChanges)

        let fresh = ModelContext(store.container)
        let transaction = try #require(try fresh.fetch(FetchDescriptor<MoneyTransaction>()).first)
        #expect(transaction.subcategory?.name == "Ngopi")
        #expect(transaction.subcategory?.emoji == "🫖")
        #expect(transaction.kind == .expense && transaction.group == .keinginan, "kind and group never change (D-004)")
        let rollup = try #require(try fresh.fetch(FetchDescriptor<MonthlyRollup>()).first)
        #expect(rollup.name == "Kopi" && rollup.emoji == "☕")
        #expect(try savedSubcategory(store, named: "Kopi") == nil)
    }

    @Test func renamingKeepsThePinAndPlace() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        let place = kopi.sortOrder
        try ledger.updateSubcategory(kopi, name: "Ngopi", emoji: "☕", monthlyBudget: nil)
        #expect(try saved(store).pinnedSubcategories().map(\.name) == ["Makan", "Ngopi", "Jajan", "Parkir", "Galon", "Hiburan"])
        #expect(kopi.sortOrder == place)
    }

    @Test func aSubcategoryMayChangeTheCaseOfItsOwnName() throws {
        let (store, ledger) = try makeStore()
        let wifi = try store.subcategory(named: "WiFi")
        try ledger.updateSubcategory(wifi, name: "Wifi", emoji: wifi.emoji, monthlyBudget: nil)
        #expect(try savedSubcategory(store, named: "Wifi") != nil)
    }

    @Test func renameRefusesAnotherSubcategorysName() throws {
        let (store, ledger) = try makeStore()
        let jajan = try store.subcategory(named: "Jajan")
        #expect(throws: SubcategoryError.invalidName(.taken)) {
            try ledger.updateSubcategory(jajan, name: "kopi", emoji: "🍿", monthlyBudget: nil)
        }
        #expect(jajan.name == "Jajan", "nothing changed")
        #expect(!store.context.hasChanges)
    }

    @Test func updateRefusesABadNameOrEmoji() throws {
        let (store, ledger) = try makeStore()
        let jajan = try store.subcategory(named: "Jajan")
        #expect(throws: SubcategoryError.invalidName(.notOneWord)) {
            try ledger.updateSubcategory(jajan, name: "Jajan sore", emoji: "🍿", monthlyBudget: nil)
        }
        #expect(throws: SubcategoryError.invalidEmoji) {
            try ledger.updateSubcategory(jajan, name: "Camilan", emoji: "x", monthlyBudget: nil)
        }
        #expect(jajan.name == "Jajan" && jajan.emoji == "🍿")
        #expect(!store.context.hasChanges)
    }

    @Test func updateSetsAndClearsTheBudget() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try ledger.updateSubcategory(kopi, name: "Kopi", emoji: "☕", monthlyBudget: 300_000)
        #expect(try savedSubcategory(store, named: "Kopi")?.monthlyBudget == 300_000)
        try ledger.updateSubcategory(kopi, name: "Kopi", emoji: "☕", monthlyBudget: 0)
        #expect(try savedSubcategory(store, named: "Kopi")?.monthlyBudget == nil, "zero is not a budget (D-062)")
    }

    @Test func updateRefusesABadBudget() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        #expect(throws: BudgetError.overMaximum) {
            try ledger.updateSubcategory(kopi, name: "Ngopi", emoji: "☕", monthlyBudget: AmountEntry.maximum + 1)
        }
        #expect(kopi.name == "Kopi", "the valid name wasn't applied either")
        let gaji = try store.subcategory(named: "Gaji")
        #expect(throws: BudgetError.incomeHasNoBudget) {
            try ledger.updateSubcategory(gaji, name: "Gaji", emoji: "💼", monthlyBudget: 1)
        }
        try ledger.updateSubcategory(gaji, name: "Upah", emoji: "💼", monthlyBudget: nil)
        #expect(gaji.name == "Upah")
        #expect(!store.context.hasChanges)
    }

    @Test func anUnchangedUpdateDoesNotSave() throws {
        let (store, _) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try failingLedger(store).updateSubcategory(kopi, name: " Kopi ", emoji: "☕", monthlyBudget: 0)
    }

    // MARK: - Reorder

    @Test func moveReordersOneSection() throws {
        let (store, ledger) = try makeStore()
        try ledger.moveSubcategories(kind: .expense, group: .keinginan, fromOffsets: [0], toOffset: 3)
        #expect(!store.context.hasChanges)
        let keinginan = SeedData.keinginan.map(\.name)
        #expect(try gridNames(saved(store), kind: .expense, group: .keinginan) == [keinginan[1], keinginan[2], keinginan[0]] + keinginan[3...])
        #expect(try gridNames(saved(store), kind: .expense, group: .kebutuhan) == SeedData.kebutuhan.map(\.name))
        let orders = try ledger.subcategories(of: .expense).filter { $0.group == .keinginan }.map(\.sortOrder)
        #expect(orders == Array(0..<keinginan.count))
    }

    @Test func moveIncome() throws {
        let (store, ledger) = try makeStore()
        try ledger.moveSubcategories(kind: .income, group: nil, fromOffsets: [7], toOffset: 0)
        let income = SeedData.income.map(\.name)
        #expect(try gridNames(saved(store), kind: .income, group: nil) == [income[7]] + income[0..<7])
    }

    /// Offsets index the visible rows; hidden ones go to the end of the section, in their old order.
    @Test func moveSkipsHiddenOnesAndPutsThemLast() throws {
        let (store, ledger) = try makeStore()
        // Keinginan: Kopi, Jajan, Nongkrong, Delivery, …
        try ledger.hide(try store.subcategory(named: "Jajan"))
        try ledger.moveSubcategories(kind: .expense, group: .keinginan, fromOffsets: [1], toOffset: 0) // Nongkrong first
        let section = try ledger.subcategories(of: .expense).filter { $0.group == .keinginan }
        #expect(section.prefix(3).map(\.name) == ["Nongkrong", "Kopi", "Delivery"])
        #expect(section.last?.name == "Jajan")
        #expect(section.map(\.sortOrder) == Array(0..<section.count))
    }

    @Test func aMoveToTheSamePlaceDoesNotSave() throws {
        let (store, _) = try makeStore()
        try failingLedger(store).moveSubcategories(kind: .expense, group: .kebutuhan, fromOffsets: [2], toOffset: 2)
    }

    @Test func moveRefusesABadPlacement() throws {
        let (_, ledger) = try makeStore()
        #expect(throws: SubcategoryError.invalidPlacement) {
            try ledger.moveSubcategories(kind: .income, group: .kebutuhan, fromOffsets: [0], toOffset: 2)
        }
    }

    // MARK: - Remove

    @Test func removingOneWithoutHistoryDeletesIt() throws {
        let (store, ledger) = try makeStore()
        let kado = try store.subcategory(named: "Kado")
        #expect(try ledger.removal(for: kado) == .delete)
        #expect(try ledger.removeSubcategory(kado) == .delete)
        #expect(!store.context.hasChanges)
        #expect(try savedSubcategory(store, named: "Kado") == nil)
        #expect(try store.subcategories().count == 43)
    }

    @Test func deletingAPinClosesTheGap() throws {
        let (store, ledger) = try makeStore()
        try ledger.removeSubcategory(try store.subcategory(named: "Jajan"))
        let pins = try saved(store).pinnedSubcategories()
        #expect(pins.map(\.name) == ["Makan", "Kopi", "Parkir", "Galon", "Hiburan"])
        #expect(pins.compactMap(\.pinOrder) == Array(0..<5))
    }

    /// With transactions it is hidden and unpinned instead, and the history stays (D-006, D-049).
    @Test func removingOneWithTransactionsHidesIt() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try log(ledger, 18_000, into: kopi)
        #expect(try ledger.removal(for: kopi) == .hide)
        #expect(try ledger.removeSubcategory(kopi) == .hide)
        let savedKopi = try #require(try savedSubcategory(store, named: "Kopi"))
        #expect(savedKopi.isHidden)
        #expect(savedKopi.pinOrder == nil)
        #expect(try saved(store).pinnedSubcategories().map(\.name) == ["Makan", "Jajan", "Parkir", "Galon", "Hiburan"])
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<MoneyTransaction>()) == 1)
        #expect(try !gridNames(saved(store), kind: .expense, group: .keinginan).contains("Kopi"))
    }

    /// A purged month's rollup is history too (D-006, D-059).
    @Test func removingOneWithOnlyARollupHidesIt() throws {
        let (store, ledger) = try makeStore()
        let dapur = try store.subcategory(named: "Dapur")
        store.context.insert(MonthlyRollup(
            month: MonthKey(year: 2024, month: 3), subcategoryID: dapur.id, total: 400_000, count: 3,
            name: "Dapur", emoji: "🥬", kind: .expense, group: .kebutuhan
        ))
        try store.context.save()
        #expect(try ledger.removal(for: dapur) == .hide)
        try ledger.removeSubcategory(dapur)
        #expect(dapur.isHidden)
    }

    @Test func removingAHiddenOneWithHistoryChangesNothing() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try log(ledger, 18_000, into: kopi)
        try ledger.removeSubcategory(kopi)
        #expect(try failingLedger(store).removeSubcategory(kopi) == .hide)
        #expect(kopi.isHidden)
    }

    /// A hidden subcategory whose history was deleted afterwards can be deleted for good.
    @Test func aHiddenOneWithoutHistoryCanBeDeleted() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        let transaction = try ledger.addTransaction(amount: 18_000, subcategory: kopi, date: now, note: nil, now: now)
        try ledger.removeSubcategory(kopi)
        try ledger.deleteTransaction(transaction)
        #expect(try ledger.removal(for: kopi) == .delete)
        try ledger.removeSubcategory(kopi)
        #expect(try savedSubcategory(store, named: "Kopi") == nil)
    }

    /// The last visible one of a group can't go, so the add sheet always has a tile there (D-062).
    @Test func theLastVisibleOfAGroupStays() throws {
        let (store, ledger) = try makeStore()
        let keinginan = try ledger.subcategories(of: .expense).filter { $0.group == .keinginan }
        for subcategory in keinginan.dropLast() {
            try ledger.removeSubcategory(subcategory)
        }
        let last = try #require(keinginan.last)
        #expect(try ledger.removal(for: last) == .notAllowed)
        #expect(throws: SubcategoryError.lastVisibleInSection) { try ledger.removeSubcategory(last) }
        #expect(try savedSubcategory(store, named: last.name)?.isHidden == false)
        // Kebutuhan is another group: its subcategories can still go.
        #expect(try ledger.removal(for: try store.subcategory(named: "Servis")) == .delete)
    }

    @Test func theLastVisibleIncomeStays() throws {
        let (store, ledger) = try makeStore()
        let gaji = try store.subcategory(named: "Gaji")
        try log(ledger, 8_500_000, into: gaji)
        for subcategory in try ledger.subcategories(of: .income) where subcategory.name != "Lainnya" {
            try ledger.removeSubcategory(subcategory)
        }
        #expect(gaji.isHidden, "with history it was hidden")
        #expect(try ledger.subcategories(of: .income).map(\.name) == ["Gaji", "Lainnya"])
        let lainnya = try store.subcategory(named: "Lainnya")
        #expect(throws: SubcategoryError.lastVisibleInSection) { try ledger.removeSubcategory(lainnya) }
        // Showing Gaji again frees Lainnya.
        try ledger.unhide(gaji)
        #expect(try ledger.removal(for: lainnya) == .delete)
    }

    /// A deleted or renamed seed subcategory never comes back on the next launch (D-006, D-062).
    @Test func theSeederDoesNotBringBackDeletedOrRenamedSubcategories() throws {
        let (store, ledger) = try makeStore()
        try ledger.removeSubcategory(try store.subcategory(named: "Kado"))
        try ledger.updateSubcategory(try store.subcategory(named: "Kopi"), name: "Ngopi", emoji: "☕", monthlyBudget: nil)

        let relaunch = ModelContext(store.container)
        #expect(try !Seeder.seedIfNeeded(in: relaunch))

        let names = try relaunch.fetch(FetchDescriptor<Subcategory>()).map(\.name)
        #expect(names.count == 43)
        #expect(!names.contains("Kado"))
        #expect(!names.contains("Kopi"))
        #expect(names.contains("Ngopi"))
    }

    // MARK: - Budgets

    @Test func groupBudgetsSetAndClear() throws {
        let (store, ledger) = try makeStore()
        try ledger.setGroupBudget(3_000_000, for: .kebutuhan)
        try ledger.setGroupBudget(500_000, for: .keinginan)
        #expect(!store.context.hasChanges)
        var settings = try AppSettings.fetchOrCreate(in: ModelContext(store.container))
        #expect(settings.budget(for: .kebutuhan) == 3_000_000)
        #expect(settings.budget(for: .keinginan) == 500_000)

        try ledger.setGroupBudget(0, for: .kebutuhan)
        try ledger.setGroupBudget(nil, for: .keinginan)
        settings = try AppSettings.fetchOrCreate(in: ModelContext(store.container))
        #expect(settings.budget(for: .kebutuhan) == nil, "zero is not a budget (D-062)")
        #expect(settings.budget(for: .keinginan) == nil)
        #expect(try store.context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }

    @Test func groupBudgetAtTheKeypadMaximum() throws {
        let (store, ledger) = try makeStore()
        try ledger.setGroupBudget(AmountEntry.maximum, for: .kebutuhan)
        #expect(throws: BudgetError.overMaximum) { try ledger.setGroupBudget(AmountEntry.maximum + 1, for: .kebutuhan) }
        #expect(try AppSettings.fetchOrCreate(in: store.context).budget(for: .kebutuhan) == AmountEntry.maximum)
        #expect(!store.context.hasChanges)
    }

    @Test func aGroupBudgetOnAStoreWithoutSettingsCreatesThem() throws {
        let store = try TestStore()
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        try ledger.setGroupBudget(nil, for: .kebutuhan)
        #expect(!store.context.hasChanges, "the inserted settings row isn't left pending")
        try ledger.setGroupBudget(1_000_000, for: .keinginan)
        #expect(try AppSettings.fetchOrCreate(in: ModelContext(store.container)).budget(for: .keinginan) == 1_000_000)
    }

    @Test func subcategoryBudgetsSetAndClear() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try ledger.setMonthlyBudget(300_000, for: kopi)
        #expect(try saved(store).subcategoryBudgets() == [kopi.id: 300_000])
        try ledger.setMonthlyBudget(0, for: kopi)
        #expect(try saved(store).subcategoryBudgets().isEmpty)
    }

    @Test func subcategoryBudgetRules() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        let gaji = try store.subcategory(named: "Gaji")
        #expect(throws: BudgetError.overMaximum) { try ledger.setMonthlyBudget(AmountEntry.maximum + 1, for: kopi) }
        #expect(throws: BudgetError.incomeHasNoBudget) { try ledger.setMonthlyBudget(50_000, for: gaji) }
        try ledger.setMonthlyBudget(nil, for: gaji)
        #expect(kopi.monthlyBudget == nil && gaji.monthlyBudget == nil)
        #expect(!store.context.hasChanges)
    }

    // MARK: - Failed saves roll back (the save is swapped, as in LedgerWriteTests)

    private struct SaveFailed: Error {}

    private func failingLedger(_ store: TestStore) -> Ledger {
        Ledger(context: store.context, timeZone: Fixtures.jakarta) { _ in throw SaveFailed() }
    }

    @Test func failedAddLeavesNothingPending() throws {
        let (store, _) = try makeStore()
        #expect(throws: SaveFailed.self) {
            try failingLedger(store).addSubcategory(name: "Bakso", emoji: "🍜", kind: .expense, group: .keinginan, now: now)
        }
        #expect(!store.context.hasChanges)
        #expect(try store.subcategories().count == 44)
        #expect(try Ledger(context: store.context, timeZone: Fixtures.jakarta).nameProblem(for: "Bakso") == nil, "the name is free again")
    }

    @Test func failedUpdateRestoresEveryField() throws {
        let (store, _) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        #expect(throws: SaveFailed.self) {
            try failingLedger(store).updateSubcategory(kopi, name: "Ngopi", emoji: "🫖", monthlyBudget: 300_000)
        }
        #expect(kopi.name == "Kopi" && kopi.emoji == "☕" && kopi.monthlyBudget == nil)
        #expect(!store.context.hasChanges)
    }

    @Test func failedMoveRestoresTheOrder() throws {
        let (store, _) = try makeStore()
        #expect(throws: SaveFailed.self) {
            try failingLedger(store).moveSubcategories(kind: .expense, group: .kebutuhan, fromOffsets: [0], toOffset: 5)
        }
        #expect(!store.context.hasChanges)
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        #expect(try gridNames(ledger, kind: .expense, group: .kebutuhan) == SeedData.kebutuhan.map(\.name))
    }

    @Test func failedDeleteRestoresTheSubcategoryAndThePins() throws {
        let (store, _) = try makeStore()
        let jajan = try store.subcategory(named: "Jajan")
        #expect(throws: SaveFailed.self) { try failingLedger(store).removeSubcategory(jajan) }
        #expect(!store.context.hasChanges)
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        let pins = try ledger.pinnedSubcategories()
        #expect(pins.map(\.name) == ["Makan", "Kopi", "Jajan", "Parkir", "Galon", "Hiburan"])
        #expect(pins.compactMap(\.pinOrder) == Array(0..<6), "the renumbered pins went back too")
        #expect(try store.subcategories().count == 44)
    }

    @Test func failedHideRestoresVisibilityAndThePin() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try log(ledger, 18_000, into: kopi)
        #expect(throws: SaveFailed.self) { try failingLedger(store).removeSubcategory(kopi) }
        #expect(!kopi.isHidden && kopi.pinOrder == 1)
        #expect(!store.context.hasChanges)
    }

    @Test func failedBudgetWritesRestoreTheOldBudget() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try ledger.setMonthlyBudget(300_000, for: kopi)
        try ledger.setGroupBudget(500_000, for: .keinginan)
        #expect(throws: SaveFailed.self) { try failingLedger(store).setMonthlyBudget(0, for: kopi) }
        #expect(throws: SaveFailed.self) { try failingLedger(store).setGroupBudget(900_000, for: .keinginan) }
        #expect(kopi.monthlyBudget == 300_000)
        #expect(try AppSettings.fetchOrCreate(in: store.context).budget(for: .keinginan) == 500_000)
        #expect(!store.context.hasChanges)
    }
}
