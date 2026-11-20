import Foundation
@testable import KemanayaCore
import SwiftData
import Testing

/// Rollup and purge (D-017, D-059): months before the raw window become rollups, one save per month.
struct RetentionTests {
    /// 20 Nov 2026, so the window starts on 1 Nov 2025 (Jakarta).
    private let now = Fixtures.date(2026, 11, 20)
    private let zone = Fixtures.jakarta

    private func seededStore() throws -> TestStore {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        return store
    }

    private func insert(_ amount: Int64, _ subcategory: Subcategory, _ date: Date, in store: TestStore) {
        store.context.insert(MoneyTransaction(amount: amount, subcategory: subcategory, date: date))
    }

    private func transactions(_ store: TestStore) throws -> [MoneyTransaction] {
        try store.context.fetch(FetchDescriptor<MoneyTransaction>(sortBy: [SortDescriptor(\.date)]))
    }

    private func rollups(_ store: TestStore) throws -> [MonthlyRollup] {
        try store.context.fetch(FetchDescriptor<MonthlyRollup>(sortBy: [SortDescriptor(\.monthKey), SortDescriptor(\.name)]))
    }

    @Test func nothingOlderThanTheWindowIsANoOp() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        insert(25_000, makan, Fixtures.date(2025, 11, 1, 0), in: store)
        insert(30_000, makan, Fixtures.date(2026, 11, 3), in: store)
        try store.context.save()

        let report = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(report.isEmpty)
        #expect(report.purgedTransactionCount == 0)
        #expect(try transactions(store).count == 2)
        #expect(try rollups(store).isEmpty)
    }

    @Test func anEmptyStoreIsANoOp() throws {
        let store = try TestStore()
        #expect(try Retention.run(in: store.context, now: now, timeZone: zone).isEmpty)
    }

    /// In Nov 2026, Oct 2025 and older are rolled up and purged; Nov 2025 stays raw (D-017's example).
    @Test func rollsUpExactlyTheMonthsBeforeTheWindow() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        let kopi = try store.subcategory(named: "Kopi")
        insert(40_000, makan, Fixtures.date(2025, 10, 5), in: store)
        insert(10_000, makan, Fixtures.date(2025, 10, 31, 23, 59, 59), in: store)
        insert(18_000, kopi, Fixtures.date(2025, 10, 12), in: store)
        insert(22_000, kopi, Fixtures.date(2025, 11, 1, 0), in: store)
        insert(30_000, makan, Fixtures.date(2025, 11, 15), in: store)
        try store.context.save()

        let report = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(report.rolledUpMonths == [MonthKey(year: 2025, month: 10)])
        #expect(report.purgedTransactionCount == 3)
        #expect(try transactions(store).map(\.amount) == [22_000, 30_000], "November 2025 is the window's first month")

        let october = try rollups(store)
        #expect(october.count == 2)
        let makanRollup = try #require(october.first { $0.subcategoryID == makan.id })
        #expect(makanRollup.monthKey == 202510)
        #expect(makanRollup.total == 50_000)
        #expect(makanRollup.count == 2)
        let kopiRollup = try #require(october.first { $0.subcategoryID == kopi.id })
        #expect(kopiRollup.total == 18_000)
        #expect(kopiRollup.count == 1)
    }

    /// An app left closed for months catches up, oldest month first, across a year boundary.
    @Test func catchesUpSeveralMonthsOldestFirst() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        insert(3_000, makan, Fixtures.date(2025, 8, 2), in: store)
        insert(1_000, makan, Fixtures.date(2024, 12, 31), in: store)
        insert(2_000, makan, Fixtures.date(2025, 1, 1, 0), in: store)
        insert(4_000, makan, Fixtures.date(2025, 10, 30), in: store)
        try store.context.save()

        let report = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(report.rolledUpMonths == [
            MonthKey(year: 2024, month: 12), MonthKey(year: 2025, month: 1), MonthKey(year: 2025, month: 8), MonthKey(year: 2025, month: 10),
        ])
        #expect(report.purgedTransactionCount == 4)
        #expect(try transactions(store).isEmpty)
        #expect(try rollups(store).map(\.monthKey) == [202412, 202501, 202508, 202510])
        #expect(try rollups(store).map(\.total) == [1_000, 2_000, 3_000, 4_000])
    }

    /// A rollup already there (e.g. from a restore) is added to, not replaced, and its snapshots refreshed.
    @Test func addsIntoAnExistingRollupAndRefreshesItsSnapshots() throws {
        let store = try seededStore()
        let kopi = try store.subcategory(named: "Kopi")
        let october = MonthKey(year: 2025, month: 10)
        store.context.insert(MonthlyRollup(
            month: october, subcategoryID: kopi.id, total: 100_000, count: 4,
            name: "Ngopi", emoji: "🫖", kind: .expense, group: .keinginan
        ))
        insert(18_000, kopi, Fixtures.date(2025, 10, 12), in: store)
        insert(7_000, kopi, Fixtures.date(2025, 10, 13), in: store)
        try store.context.save()

        try Retention.run(in: store.context, now: now, timeZone: zone)
        let all = try rollups(store)
        #expect(all.count == 1, "one row per (month, subcategory)")
        let rollup = try #require(all.first)
        #expect(rollup.total == 125_000)
        #expect(rollup.count == 6)
        #expect(rollup.name == "Kopi")
        #expect(rollup.emoji == kopi.emoji)
    }

    /// Name, emoji, kind and group are copied, and income keeps no group.
    @Test func snapshotsKindAndGroup() throws {
        let store = try seededStore()
        let gaji = try store.subcategory(named: "Gaji")
        let makan = try store.subcategory(named: "Makan")
        let kopi = try store.subcategory(named: "Kopi")
        insert(8_500_000, gaji, Fixtures.date(2025, 9, 25), in: store)
        insert(50_000, makan, Fixtures.date(2025, 9, 3), in: store)
        insert(18_000, kopi, Fixtures.date(2025, 9, 4), in: store)
        try store.context.save()

        try Retention.run(in: store.context, now: now, timeZone: zone)
        let all = try rollups(store)
        let income = try #require(all.first { $0.subcategoryID == gaji.id })
        #expect(income.kind == .income)
        #expect(income.group == nil)
        #expect(income.name == "Gaji")
        #expect(income.emoji == gaji.emoji)
        let need = try #require(all.first { $0.subcategoryID == makan.id })
        #expect(need.kind == .expense)
        #expect(need.group == .kebutuhan)
        let want = try #require(all.first { $0.subcategoryID == kopi.id })
        #expect(want.group == .keinginan)
        #expect(want.name == "Kopi")

        // The month's totals read the same from the rollups as they did from the raw rows.
        let september = MonthKey(year: 2025, month: 9)
        let summary = try Ledger(context: store.context, timeZone: zone).monthTotals(from: september, through: september).summary(for: september)
        #expect(summary.income == 8_500_000)
        #expect(summary.kebutuhan == 50_000)
        #expect(summary.keinginan == 18_000)
    }

    /// A subcategory renamed after rolling up keeps its old name in the rollup (D-017's snapshot).
    @Test func snapshotsDoNotFollowLaterRenames() throws {
        let store = try seededStore()
        let kopi = try store.subcategory(named: "Kopi")
        insert(18_000, kopi, Fixtures.date(2025, 9, 4), in: store)
        try store.context.save()
        try Retention.run(in: store.context, now: now, timeZone: zone)
        kopi.name = "Kafein"
        try store.context.save()
        #expect(try rollups(store).first?.name == "Kopi")
    }

    /// 23:30 on 31 Oct 2025 in Jakarta is October there (rolled up); 00:30 on 1 Nov 2025 is November
    /// (kept), although both are 31 Oct in UTC.
    @Test func monthBoundaryFollowsTheDeviceTimeZone() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        insert(11_000, makan, Fixtures.date(2025, 10, 31, 23, 30), in: store)
        insert(22_000, makan, Fixtures.date(2025, 11, 1, 0, 30), in: store)
        try store.context.save()

        let report = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(report.rolledUpMonths == [MonthKey(year: 2025, month: 10)])
        #expect(try transactions(store).map(\.amount) == [22_000])
        #expect(try rollups(store).map(\.total) == [11_000])
        #expect(try rollups(store).map(\.monthKey) == [202510])
    }

    @Test func runningTwiceChangesNothingTheSecondTime() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        insert(40_000, makan, Fixtures.date(2025, 10, 5), in: store)
        insert(30_000, makan, Fixtures.date(2025, 11, 15), in: store)
        try store.context.save()

        #expect(try Retention.run(in: store.context, now: now, timeZone: zone).rolledUpMonths.count == 1)
        let second = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(second.isEmpty)
        #expect(try rollups(store).map(\.total) == [40_000], "never counted twice")
        #expect(try transactions(store).map(\.amount) == [30_000])
    }

    /// When the month moves on, the next run rolls up exactly the month that left the window.
    @Test func aNewMonthRollsUpTheMonthThatLeftTheWindow() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        insert(30_000, makan, Fixtures.date(2025, 11, 15), in: store)
        insert(20_000, makan, Fixtures.date(2025, 12, 15), in: store)
        try store.context.save()

        #expect(try Retention.run(in: store.context, now: now, timeZone: zone).isEmpty)
        let december = try Retention.run(in: store.context, now: Fixtures.date(2026, 12, 1, 0, 5), timeZone: zone)
        #expect(december.rolledUpMonths == [MonthKey(year: 2025, month: 11)])
        #expect(try transactions(store).map(\.amount) == [20_000])
    }

    /// A failed save leaves the month all raw: no new rollup, the existing one back to its old total,
    /// and every transaction still there. The months before it stay rolled up.
    @Test func aFailedSaveLeavesTheMonthRaw() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        let september = MonthKey(year: 2025, month: 9)
        let october = MonthKey(year: 2025, month: 10)
        store.context.insert(MonthlyRollup(
            month: october, subcategoryID: makan.id, total: 1_000, count: 1,
            name: "Makan", emoji: makan.emoji, kind: .expense, group: .kebutuhan
        ))
        insert(9_000, makan, Fixtures.date(2025, 9, 5), in: store)
        insert(40_000, makan, Fixtures.date(2025, 10, 5), in: store)
        insert(5_000, try store.subcategory(named: "Kopi"), Fixtures.date(2025, 10, 6), in: store)
        try store.context.save()

        struct SaveFailed: Error {}
        var saves = 0
        #expect(throws: SaveFailed.self) {
            try Retention.run(in: store.context, now: now, timeZone: zone) { context in
                saves += 1
                if saves == 2 { throw SaveFailed() }
                try context.save()
            }
        }
        #expect(try transactions(store).map(\.amount) == [40_000, 5_000], "October is still raw")
        let all = try rollups(store)
        #expect(all.map(\.monthKey) == [september.rawValue, october.rawValue], "no half-made October rollup")
        #expect(all.map(\.total) == [9_000, 1_000], "the existing rollup is back to its old total")
        #expect(all.last?.count == 1)
        let octoberMakan = try transactions(store).filter { $0.amount == 40_000 }
        #expect(makan.transactions.map(\.amount) == [40_000], "the relationship is intact after the rollback")
        #expect(octoberMakan.first?.subcategory?.id == makan.id)

        // The next run finishes the job.
        let retry = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(retry.rolledUpMonths == [october])
        #expect(try rollups(store).filter { $0.monthKey == october.rawValue }.map(\.total).sorted() == [5_000, 41_000])
    }

    /// Unsaved changes elsewhere (an edit in progress) are neither committed nor thrown away: the run is
    /// skipped and the next one does the work.
    @Test func pendingChangesSkipTheRun() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        insert(40_000, makan, Fixtures.date(2025, 9, 5), in: store)
        try store.context.save()

        // Pending: a new entry, and an edit to a saved one.
        insert(12_000, makan, Fixtures.date(2026, 11, 2), in: store)
        let old = try #require(try transactions(store).first { $0.amount == 40_000 })
        old.setNote("edited")
        #expect(store.context.hasChanges)

        let report = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(report.skippedForPendingChanges)
        #expect(report.isEmpty)
        #expect(store.context.hasChanges, "the pending changes are still pending")
        #expect(old.note == "edited")
        #expect(try transactions(store).map(\.amount) == [40_000, 12_000])
        #expect(try ModelContext(store.container).fetchCount(FetchDescriptor<MoneyTransaction>()) == 1, "and not saved")
        #expect(try rollups(store).isEmpty)

        // Once they are saved, the next run rolls September up.
        try store.context.save()
        let next = try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(!next.skippedForPendingChanges)
        #expect(next.rolledUpMonths == [MonthKey(year: 2025, month: 9)])
        #expect(try transactions(store).map(\.amount) == [12_000])
    }

    /// Adding into an existing rollup clamps at Int64's limit instead of trapping.
    @Test func addingIntoAHugeRollupClamps() throws {
        let store = try seededStore()
        let makan = try store.subcategory(named: "Makan")
        let september = MonthKey(year: 2025, month: 9)
        store.context.insert(MonthlyRollup(
            month: september, subcategoryID: makan.id, total: .max - 10, count: 1,
            name: "Makan", emoji: makan.emoji, kind: .expense, group: .kebutuhan
        ))
        insert(AmountEntry.maximum, makan, Fixtures.date(2025, 9, 5), in: store)
        try store.context.save()

        try Retention.run(in: store.context, now: now, timeZone: zone)
        #expect(try rollups(store).map(\.total) == [.max])
        #expect(try rollups(store).map(\.count) == [2])
    }

    /// An orphaned transaction (its subcategory deleted, D-006) is still counted, with no name snapshot.
    @Test func anOrphanIsRolledUpWithoutANameSnapshot() throws {
        let store = try seededStore()
        let hiburan = try store.subcategory(named: "Hiburan")
        let id = hiburan.id
        insert(75_000, hiburan, Fixtures.date(2025, 7, 7), in: store)
        try store.context.save()
        store.context.delete(hiburan)
        try store.context.save()

        try Retention.run(in: store.context, now: now, timeZone: zone)
        let rollup = try #require(try rollups(store).first)
        #expect(rollup.subcategoryID == id)
        #expect(rollup.total == 75_000)
        #expect(rollup.name.isEmpty)
        #expect(rollup.group == .keinginan)
    }
}
