import Foundation
import KemanayaCore
import Testing

/// Riwayat's filter (D-074): groups and subcategories, multi-select, AND between the two parts, and the
/// month header's figures under it.
struct HistoryFilterTests {
    private let makan = UUID()
    private let galon = UUID()
    private let kopi = UUID()
    private let gaji = UUID()
    private let unknown = UUID()

    private var sections: [UUID: PinSection] {
        [makan: .kebutuhan, galon: .kebutuhan, kopi: .keinginan, gaji: .pemasukan]
    }

    private func sectionOf(_ id: UUID) -> PinSection? { sections[id] }

    private func row(_ amount: Int64, _ subcategory: UUID, day: Int = 19) -> TransactionSnapshot {
        let section = sections[subcategory] ?? .kebutuhan
        return TransactionSnapshot(
            amount: amount,
            kind: section.kind,
            group: section == .pemasukan ? nil : (section == .keinginan ? .keinginan : .kebutuhan),
            subcategoryID: subcategory,
            date: Fixtures.date(2026, 11, day)
        )
    }

    private var rows: [TransactionSnapshot] {
        [row(50_000, makan), row(30_000, galon), row(18_000, kopi), row(8_500_000, gaji)]
    }

    private func amounts(_ filter: HistoryFilter) -> [Int64] {
        rows.filter(filter.matches).map(\.amount)
    }

    // MARK: - Matching

    @Test func emptyFilterMatchesEverything() {
        let filter = HistoryFilter()
        #expect(filter.isEmpty)
        #expect(filter.count == 0)
        #expect(amounts(filter) == [50_000, 30_000, 18_000, 8_500_000])
    }

    @Test func eachGroupMatchesItsRows() {
        #expect(amounts(HistoryFilter(groups: [.kebutuhan])) == [50_000, 30_000])
        #expect(amounts(HistoryFilter(groups: [.keinginan])) == [18_000])
        #expect(amounts(HistoryFilter(groups: [.pemasukan])) == [8_500_000])
    }

    @Test func groupsCombineAsAnyOf() {
        #expect(amounts(HistoryFilter(groups: [.kebutuhan, .keinginan])) == [50_000, 30_000, 18_000], "all spending")
        #expect(amounts(HistoryFilter(groups: [.keinginan, .pemasukan])) == [18_000, 8_500_000])
        #expect(amounts(HistoryFilter(groups: Set(PinSection.allCases))) == [50_000, 30_000, 18_000, 8_500_000])
    }

    @Test func incomeNeverMatchesTheExpenseGroups() {
        let income = row(8_500_000, gaji)
        #expect(!HistoryFilter(groups: [.kebutuhan]).matches(income))
        #expect(!HistoryFilter(groups: [.keinginan]).matches(income))
        #expect(!HistoryFilter(groups: [.kebutuhan, .keinginan]).matches(income))
        #expect(HistoryFilter().matches(income), "no filter: income passes")
        #expect(HistoryFilter(groups: [.pemasukan]).matches(income))
        #expect(!HistoryFilter(groups: [.keinginan]).matches(kind: .income, group: .keinginan, subcategoryID: gaji),
                "income is Pemasukan whatever group it carries")
    }

    @Test func subcategoriesMatchAsAnyOf() {
        #expect(amounts(HistoryFilter(subcategoryIDs: [kopi])) == [18_000])
        #expect(amounts(HistoryFilter(subcategoryIDs: [makan, gaji])) == [50_000, 8_500_000], "across groups")
        #expect(amounts(HistoryFilter(subcategoryIDs: [unknown])).isEmpty)
    }

    @Test func groupsAndSubcategoriesCombineWithAnd() {
        #expect(amounts(HistoryFilter(groups: [.kebutuhan], subcategoryIDs: [galon])) == [30_000])
        #expect(amounts(HistoryFilter(groups: [.kebutuhan], subcategoryIDs: [kopi])).isEmpty, "Kopi isn't a need")
    }

    @Test func countIsOnePerChip() {
        #expect(HistoryFilter(groups: [.kebutuhan, .pemasukan], subcategoryIDs: [kopi]).count == 3)
        #expect(!HistoryFilter(subcategoryIDs: [kopi]).isEmpty)
    }

    // MARK: - Editing

    @Test func togglingAGroupOffDropsItsSubcategories() {
        let filter = HistoryFilter(groups: [.kebutuhan, .keinginan], subcategoryIDs: [makan, kopi])
        let toggled = filter.toggling(.keinginan, sectionOf: sectionOf)
        #expect(toggled == HistoryFilter(groups: [.kebutuhan], subcategoryIDs: [makan]))
        // The last group off keeps the other groups' subcategories.
        #expect(HistoryFilter(groups: [.keinginan], subcategoryIDs: [kopi, makan]).toggling(.keinginan, sectionOf: sectionOf)
                == HistoryFilter(subcategoryIDs: [makan]))
    }

    @Test func togglingAGroupOnDropsSubcategoriesOutsideTheSelection() {
        let filter = HistoryFilter(subcategoryIDs: [makan, kopi, gaji])
        #expect(filter.toggling(.kebutuhan, sectionOf: sectionOf) == HistoryFilter(groups: [.kebutuhan], subcategoryIDs: [makan]))
        #expect(HistoryFilter(groups: [.kebutuhan], subcategoryIDs: [makan]).toggling(.pemasukan, sectionOf: sectionOf)
                == HistoryFilter(groups: [.kebutuhan, .pemasukan], subcategoryIDs: [makan]))
    }

    @Test func togglingASubcategory() {
        let on = HistoryFilter().toggling(subcategory: kopi)
        #expect(on == HistoryFilter(subcategoryIDs: [kopi]))
        #expect(on.toggling(subcategory: kopi).isEmpty)
    }

    @Test func removingOneChip() {
        let filter = HistoryFilter(groups: [.keinginan, .pemasukan], subcategoryIDs: [kopi, gaji])
        #expect(filter.removing(subcategory: kopi) == HistoryFilter(groups: [.keinginan, .pemasukan], subcategoryIDs: [gaji]))
        #expect(filter.removing(.keinginan, sectionOf: sectionOf) == HistoryFilter(groups: [.pemasukan], subcategoryIDs: [gaji]),
                "a group's chip takes its subcategories with it")
        #expect(filter.removing(subcategory: unknown) == filter)
    }

    @Test func pruningKeepsOnlyTheSelectedGroupsSubcategories() {
        #expect(HistoryFilter(groups: [.keinginan], subcategoryIDs: [kopi, makan, unknown]).pruned(sectionOf: sectionOf)
                == HistoryFilter(groups: [.keinginan], subcategoryIDs: [kopi]))
        let noGroups = HistoryFilter(subcategoryIDs: [kopi, makan, unknown])
        #expect(noGroups.pruned(sectionOf: sectionOf) == noGroups, "no group selected: every subcategory stays")
    }

    @Test func offeredSections() {
        #expect(HistoryFilter().offeredSections == [.kebutuhan, .keinginan, .pemasukan])
        #expect(HistoryFilter(groups: [.pemasukan, .kebutuhan]).offeredSections == [.kebutuhan, .pemasukan], "in display order")
    }

    // MARK: - Header figures

    @Test func allowedKinds() {
        let all: Set<TransactionKind> = [.expense, .income]
        #expect(HistoryFilter().allowedKinds(sectionOf: sectionOf) == all)
        #expect(HistoryFilter(groups: [.keinginan]).allowedKinds(sectionOf: sectionOf) == [.expense])
        #expect(HistoryFilter(groups: [.kebutuhan, .keinginan]).allowedKinds(sectionOf: sectionOf) == [.expense])
        #expect(HistoryFilter(groups: [.pemasukan]).allowedKinds(sectionOf: sectionOf) == [.income])
        #expect(HistoryFilter(groups: [.keinginan, .pemasukan]).allowedKinds(sectionOf: sectionOf) == all)
        #expect(HistoryFilter(subcategoryIDs: [kopi]).allowedKinds(sectionOf: sectionOf) == [.expense], "an expense subcategory")
        #expect(HistoryFilter(subcategoryIDs: [gaji]).allowedKinds(sectionOf: sectionOf) == [.income], "an income subcategory")
        #expect(HistoryFilter(subcategoryIDs: [kopi, gaji]).allowedKinds(sectionOf: sectionOf) == all)
        #expect(HistoryFilter(subcategoryIDs: [kopi, unknown]).allowedKinds(sectionOf: sectionOf) == all, "an unknown one narrows nothing")
    }

    @Test func headerFiguresFollowTheFilter() {
        let both = HistoryTotals(expenses: 98_000, income: 8_500_000)
        let spendingOnly = HistoryTotals(expenses: 98_000)
        #expect(both.figures() == [.expense, .income], "unfiltered, D-073")
        #expect(spendingOnly.figures() == [.expense], "no income, no Pemasukan")
        #expect(HistoryTotals(income: 500_000).figures() == [.expense, .income], "Pengeluaran Rp0 beside income")
        #expect(both.figures(allowing: [.expense]) == [.expense])
        #expect(both.figures(allowing: [.income]) == [.income])
        #expect(spendingOnly.figures(allowing: [.income]).isEmpty)
        #expect(both.amount(of: .expense) == 98_000)
        #expect(both.amount(of: .income) == 8_500_000)
    }

    /// Under a filter, the header's figures are the sums of the rows that pass it.
    @Test func filteredTotalsSumTheMatchingRows() {
        let entries = rows + [row(20_000, kopi, day: 3), row(12_000, makan, day: 3)]
        func totals(_ filter: HistoryFilter) -> HistoryTotals {
            HistoryGrouping.months(entries.lazy.filter(filter.matches), timeZone: Fixtures.jakarta).first?.totals ?? HistoryTotals()
        }
        #expect(totals(HistoryFilter()) == HistoryTotals(expenses: 130_000, income: 8_500_000))
        #expect(totals(HistoryFilter(groups: [.keinginan])) == HistoryTotals(expenses: 38_000))
        #expect(totals(HistoryFilter(groups: [.kebutuhan])) == HistoryTotals(expenses: 92_000))
        #expect(totals(HistoryFilter(groups: [.pemasukan])) == HistoryTotals(income: 8_500_000))
        #expect(totals(HistoryFilter(subcategoryIDs: [kopi, gaji])) == HistoryTotals(expenses: 38_000, income: 8_500_000))
        #expect(totals(HistoryFilter(groups: [.kebutuhan], subcategoryIDs: [makan])) == HistoryTotals(expenses: 62_000))

        let keinginan = HistoryFilter(groups: [.keinginan])
        let figures = totals(keinginan).figures(allowing: keinginan.allowedKinds(sectionOf: sectionOf))
        #expect(figures == [.expense], "Keinginan shows Pengeluaran only")
    }

    /// The real models carry what the filter reads.
    @Test func matchesModels() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let kopi = try store.subcategory(named: "Kopi")
        let transaction = MoneyTransaction(amount: 18_000, subcategory: kopi, date: Fixtures.date(2026, 11, 19))
        store.context.insert(transaction)
        #expect(HistoryFilter(groups: [kopi.pinSection]).matches(transaction))
        #expect(HistoryFilter(subcategoryIDs: [kopi.id]).matches(transaction))
        #expect(!HistoryFilter(groups: [.pemasukan]).matches(transaction))
    }
}
