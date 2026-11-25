import Foundation
import KemanayaCore
import Testing

/// Riwayat's filter (D-074, D-075): three independent groups, each narrowed only by its own subcategory
/// picks, and the month header's figures under it.
struct HistoryFilterTests {
    private let makan = UUID()
    private let galon = UUID()
    private let listrik = UUID()
    private let kopi = UUID()
    private let jajan = UUID()
    private let gaji = UUID()
    private let bonus = UUID()
    private let unknown = UUID()

    private var sections: [UUID: PinSection] {
        [makan: .kebutuhan, galon: .kebutuhan, listrik: .kebutuhan, kopi: .keinginan, jajan: .keinginan,
         gaji: .pemasukan, bonus: .pemasukan]
    }

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

    /// Makan, Galon, Listrik (Kebutuhan); Kopi, Jajan (Keinginan); Gaji, Bonus (Pemasukan).
    private var rows: [TransactionSnapshot] {
        [row(50_000, makan), row(30_000, galon), row(400_000, listrik), row(18_000, kopi), row(25_000, jajan),
         row(8_500_000, gaji), row(1_000_000, bonus)]
    }

    private var allAmounts: [Int64] { rows.map(\.amount) }

    private func amounts(_ filter: HistoryFilter) -> [Int64] {
        rows.filter(filter.matches).map(\.amount)
    }

    // MARK: - Matching

    @Test func emptyFilterMatchesEverything() {
        let filter = HistoryFilter()
        #expect(filter.isEmpty)
        #expect(filter.count == 0)
        #expect(amounts(filter) == allAmounts)
        #expect(filter == HistoryFilter(groups: []))
    }

    @Test func eachGroupMatchesItsRows() {
        #expect(amounts(HistoryFilter(groups: [.kebutuhan])) == [50_000, 30_000, 400_000])
        #expect(amounts(HistoryFilter(groups: [.keinginan])) == [18_000, 25_000])
        #expect(amounts(HistoryFilter(groups: [.pemasukan])) == [8_500_000, 1_000_000])
    }

    @Test func groupsCombineAsAnyOf() {
        #expect(amounts(HistoryFilter(groups: [.kebutuhan, .keinginan])) == [50_000, 30_000, 400_000, 18_000, 25_000],
                "all spending")
        #expect(amounts(HistoryFilter(groups: [.keinginan, .pemasukan])) == [18_000, 25_000, 8_500_000, 1_000_000])
        #expect(amounts(HistoryFilter(groups: Set(PinSection.allCases))) == allAmounts)
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

    /// The bug D-075 fixes: picks under Kebutuhan hid every Keinginan row.
    @Test func picksNarrowOnlyTheirOwnGroup() {
        let filter = HistoryFilter([.kebutuhan: [makan, listrik], .keinginan: []])
        #expect(amounts(filter) == [50_000, 400_000, 18_000, 25_000], "Makan, Listrik and all of Keinginan")
        #expect(!filter.matches(row(30_000, galon)), "other needs don't pass")
        #expect(!filter.matches(row(8_500_000, gaji)), "income isn't ticked")
    }

    @Test func picksInEveryGroupShowExactlyThose() {
        let filter = HistoryFilter([.kebutuhan: [makan], .keinginan: [kopi], .pemasukan: [gaji]])
        #expect(amounts(filter) == [50_000, 18_000, 8_500_000])
    }

    @Test func aPickBesideAWholeGroup() {
        let filter = HistoryFilter([.keinginan: [kopi], .pemasukan: []])
        #expect(amounts(filter) == [18_000, 8_500_000, 1_000_000], "Kopi and all income")
    }

    @Test func aPickOfAnotherGroupsSubcategoryMatchesNothingThere() {
        #expect(amounts(HistoryFilter([.kebutuhan: [kopi]])).isEmpty, "Kopi isn't a need")
        #expect(amounts(HistoryFilter([.kebutuhan: [unknown]])).isEmpty)
    }

    @Test func countIsOnePerChip() {
        let filter = HistoryFilter([.kebutuhan: [makan, listrik], .pemasukan: []])
        #expect(filter.count == 4)
        #expect(filter.groups == [.kebutuhan, .pemasukan])
        #expect(filter.subcategoryIDs == [makan, listrik])
        #expect(filter.picks(in: .kebutuhan) == [makan, listrik])
        #expect(filter.picks(in: .keinginan).isEmpty)
        #expect(!HistoryFilter(groups: [.keinginan]).isEmpty)
    }

    // MARK: - Editing

    @Test func togglingAGroup() {
        let on = HistoryFilter().toggling(.keinginan)
        #expect(on == HistoryFilter(groups: [.keinginan]))
        #expect(on.toggling(.keinginan).isEmpty)
    }

    @Test func untickingAGroupDropsItsPicks() {
        let filter = HistoryFilter([.kebutuhan: [makan], .keinginan: [kopi]])
        #expect(filter.toggling(.keinginan) == HistoryFilter([.kebutuhan: [makan]]))
        #expect(filter.toggling(.keinginan).toggling(.keinginan) == HistoryFilter([.kebutuhan: [makan], .keinginan: []]),
                "ticking it again starts from all of the group")
        #expect(HistoryFilter([.keinginan: [kopi]]).toggling(.keinginan).isEmpty, "the last group off empties the filter")
    }

    @Test func togglingASubcategory() {
        let filter = HistoryFilter(groups: [.keinginan])
        let on = filter.toggling(subcategory: kopi, in: .keinginan)
        #expect(on == HistoryFilter([.keinginan: [kopi]]))
        #expect(on.toggling(subcategory: kopi, in: .keinginan) == filter, "unpicking keeps the group ticked")
        #expect(HistoryFilter().toggling(subcategory: kopi, in: .keinginan) == HistoryFilter([.keinginan: [kopi]]),
                "a pick ticks its group, so it never exists without it")
    }

    @Test func removingOneChip() {
        let filter = HistoryFilter([.keinginan: [kopi], .pemasukan: [gaji]])
        #expect(filter.removing(subcategory: kopi) == HistoryFilter([.keinginan: [], .pemasukan: [gaji]]))
        #expect(filter.removing(.keinginan) == HistoryFilter([.pemasukan: [gaji]]),
                "a group's chip takes its subcategories with it")
        #expect(filter.removing(subcategory: unknown) == filter)
        #expect(filter.removing(.kebutuhan) == filter)
    }

    @Test func offeredSections() {
        #expect(HistoryFilter().offeredSections.isEmpty, "no group ticked: only Jenis")
        #expect(HistoryFilter(groups: [.pemasukan, .kebutuhan]).offeredSections == [.kebutuhan, .pemasukan], "in display order")
        #expect(HistoryFilter([.keinginan: [kopi]]).offeredSections == [.keinginan])
    }

    // MARK: - Header figures

    @Test func allowedKinds() {
        let all: Set<TransactionKind> = [.expense, .income]
        #expect(HistoryFilter().allowedKinds == all)
        #expect(HistoryFilter(groups: [.keinginan]).allowedKinds == [.expense])
        #expect(HistoryFilter(groups: [.kebutuhan, .keinginan]).allowedKinds == [.expense])
        #expect(HistoryFilter(groups: [.pemasukan]).allowedKinds == [.income])
        #expect(HistoryFilter(groups: [.keinginan, .pemasukan]).allowedKinds == all)
        #expect(HistoryFilter([.kebutuhan: [makan, listrik], .keinginan: []]).allowedKinds == [.expense])
        #expect(HistoryFilter([.kebutuhan: [makan], .keinginan: [kopi], .pemasukan: [gaji]]).allowedKinds == all)
        #expect(HistoryFilter([.keinginan: [kopi], .pemasukan: []]).allowedKinds == all)
        #expect(HistoryFilter([.pemasukan: [gaji]]).allowedKinds == [.income], "a pick doesn't widen its group")
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
        let entries = [row(50_000, makan), row(30_000, galon), row(18_000, kopi), row(8_500_000, gaji),
                       row(20_000, kopi, day: 3), row(12_000, makan, day: 3)]
        func totals(_ filter: HistoryFilter) -> HistoryTotals {
            HistoryGrouping.months(entries.lazy.filter(filter.matches), timeZone: Fixtures.jakarta).first?.totals ?? HistoryTotals()
        }
        #expect(totals(HistoryFilter()) == HistoryTotals(expenses: 130_000, income: 8_500_000))
        #expect(totals(HistoryFilter(groups: [.keinginan])) == HistoryTotals(expenses: 38_000))
        #expect(totals(HistoryFilter(groups: [.kebutuhan])) == HistoryTotals(expenses: 92_000))
        #expect(totals(HistoryFilter(groups: [.pemasukan])) == HistoryTotals(income: 8_500_000))
        #expect(totals(HistoryFilter([.keinginan: [kopi], .pemasukan: [gaji]])) == HistoryTotals(expenses: 38_000, income: 8_500_000))
        #expect(totals(HistoryFilter([.kebutuhan: [makan]])) == HistoryTotals(expenses: 62_000))
        #expect(totals(HistoryFilter([.kebutuhan: [makan], .keinginan: []])) == HistoryTotals(expenses: 100_000),
                "Makan plus all of Keinginan")

        let keinginan = HistoryFilter(groups: [.keinginan])
        let figures = totals(keinginan).figures(allowing: keinginan.allowedKinds)
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
        #expect(HistoryFilter([kopi.pinSection: [kopi.id]]).matches(transaction))
        #expect(!HistoryFilter(groups: [.pemasukan]).matches(transaction))
    }
}
