import Foundation
import KemanayaCore
import SwiftData
import Testing

struct LedgerTests {
    private let november = MonthKey(year: 2026, month: 11)

    /// A seeded store with transactions around November 2026 (Jakarta time).
    private func makeStore() throws -> TestStore {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let makan = try store.subcategory(named: "Makan")
        let kopi = try store.subcategory(named: "Kopi")
        let gaji = try store.subcategory(named: "Gaji")
        let entries: [(Int64, Subcategory, Date)] = [
            (5_000_000, gaji, Fixtures.date(2026, 11, 1, 0)), // first instant of November
            (50_000, makan, Fixtures.date(2026, 11, 10)),
            (25_000, kopi, Fixtures.date(2026, 11, 12)),
            (30_000, kopi, Fixtures.date(2026, 11, 30, 23, 59, 59)), // last second of November
            (99_000, makan, Fixtures.date(2026, 10, 31, 23, 59, 59)), // October
            (77_000, kopi, Fixtures.date(2026, 12, 1, 0)), // December
        ]
        for (amount, subcategory, date) in entries {
            store.context.insert(MoneyTransaction(amount: amount, subcategory: subcategory, date: date))
        }
        try store.context.save()
        return store
    }

    @Test func fetchesOnlyTheMonthNewestFirst() throws {
        let store = try makeStore()
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        let transactions = try ledger.transactions(in: november)
        #expect(transactions.map(\.amount) == [30_000, 25_000, 50_000, 5_000_000])
    }

    @Test func filtersByKindAndGroup() throws {
        let store = try makeStore()
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        #expect(try ledger.transactions(in: november, filter: .kind(.income)).map(\.amount) == [5_000_000])
        #expect(try ledger.transactions(in: november, filter: .kind(.expense)).map(\.amount) == [30_000, 25_000, 50_000])
        #expect(try ledger.transactions(in: november, filter: .group(.keinginan)).map(\.amount) == [30_000, 25_000])
        #expect(try ledger.transactions(in: november, filter: .group(.kebutuhan)).map(\.amount) == [50_000])
    }

    @Test func otherMonthsAndTimeZones() throws {
        let store = try makeStore()
        let jakarta = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        #expect(try jakarta.transactions(in: november.previous).map(\.amount) == [99_000])
        #expect(try jakarta.transactions(in: november.next).map(\.amount) == [77_000])

        // In Los Angeles, Jakarta's 1 Nov 00:00 is still October, and Jakarta's 1 Dec 00:00 is November.
        let losAngeles = Ledger(context: store.context, timeZone: Fixtures.losAngeles)
        #expect(try losAngeles.transactions(in: november).map(\.amount) == [77_000, 30_000, 25_000, 50_000])
    }

    @Test func summaryOfTheMonth() throws {
        let store = try makeStore()
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        let summary = try ledger.summary(for: november)
        #expect(summary.income == 5_000_000)
        #expect(summary.kebutuhan == 50_000)
        #expect(summary.keinginan == 55_000)
        #expect(summary.sisa == 4_895_000)
        #expect(summary.total(for: try store.subcategory(named: "Kopi").id) == 55_000)

        let snapshots = try ledger.snapshots(in: november, filter: .group(.keinginan))
        #expect(snapshots.allSatisfy { $0.kind == .expense && $0.group == .keinginan })
        #expect(snapshots.count == 2)
    }

    @Test func pinnedSubcategoriesSkipHiddenAndFollowPinOrder() throws {
        let store = try makeStore()
        try store.subcategory(named: "Jajan").isHidden = true
        try store.subcategory(named: "Gaji").pinOrder = 6
        try store.subcategory(named: "Makan").pinOrder = 7
        try store.context.save()

        let pinned = try Ledger(context: store.context, timeZone: Fixtures.jakarta).pinnedSubcategories()
        #expect(pinned.map(\.name) == ["Kopi", "Parkir", "Galon", "Hiburan", "Gaji", "Makan"])
    }

    @Test func subcategoryBudgetsAndProgress() throws {
        let store = try makeStore()
        try store.subcategory(named: "Kopi").setMonthlyBudget(50_000)
        try store.subcategory(named: "Delivery").setMonthlyBudget(200_000)
        try store.context.save()

        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        let budgets = try ledger.subcategoryBudgets()
        let kopi = try store.subcategory(named: "Kopi").id
        let delivery = try store.subcategory(named: "Delivery").id
        #expect(budgets == [kopi: 50_000, delivery: 200_000])

        let progress = try ledger.summary(for: november).subcategoryBudgetProgress(budgets)
        #expect(progress[kopi]?.spent == 55_000)
        #expect(progress[kopi]?.isOverBudget == true)
        #expect(progress[delivery]?.spent == 0)
    }

    @Test func predicateWorksInAPlainFetchDescriptor() throws {
        let store = try makeStore()
        let range = november.dateRange(in: Fixtures.jakarta)
        let count = try store.context.fetchCount(FetchDescriptor(predicate: MoneyTransaction.predicate(in: range, filter: .kind(.expense))))
        #expect(count == 3)
    }
}
