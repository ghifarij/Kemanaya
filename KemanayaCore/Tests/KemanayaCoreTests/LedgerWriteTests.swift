import Foundation
@testable import KemanayaCore
import SwiftData
import Testing

/// Add, update and delete through ``Ledger`` (D-013, D-043, D-044).
struct LedgerWriteTests {
    private let now = Fixtures.date(2026, 11, 18, 10, 30)
    private let november = MonthKey(year: 2026, month: 11)

    private func makeStore() throws -> (TestStore, Ledger) {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        return (store, Ledger(context: store.context, timeZone: Fixtures.jakarta))
    }

    /// Reads back through a fresh context, so the test sees what was saved, not pending changes.
    private func savedTransactions(_ store: TestStore) throws -> [MoneyTransaction] {
        try ModelContext(store.container).fetch(FetchDescriptor<MoneyTransaction>())
    }

    // MARK: - Add

    @Test func addSavesTheTransaction() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let date = Fixtures.date(2026, 11, 18, 9)
        let added = try ledger.addTransaction(amount: 30_000, subcategory: makan, date: date, note: "  Nasi padang ", now: now)

        #expect(!store.context.hasChanges, "add saves the context")
        let saved = try savedTransactions(store)
        #expect(saved.count == 1)
        let transaction = try #require(saved.first)
        #expect(transaction.id == added.id)
        #expect(transaction.amount == 30_000)
        #expect(transaction.subcategoryID == makan.id)
        #expect(transaction.kind == .expense)
        #expect(transaction.group == .kebutuhan)
        #expect(transaction.date == date)
        #expect(transaction.note == "Nasi padang", "notes are trimmed")
        #expect(try ledger.transactions(in: november).map(\.id) == [added.id])
    }

    @Test func addIncome() throws {
        let (store, ledger) = try makeStore()
        let gaji = try store.subcategory(named: "Gaji")
        try ledger.addTransaction(amount: 8_500_000, subcategory: gaji, date: now, note: nil, now: now)
        let saved = try #require(try savedTransactions(store).first)
        #expect(saved.kind == .income)
        #expect(saved.group == nil)
        #expect(try ledger.summary(for: november).income == 8_500_000)
    }

    @Test func addTreatsABlankNoteAsNone() throws {
        let (store, ledger) = try makeStore()
        let added = try ledger.addTransaction(amount: 5_000, subcategory: try store.subcategory(named: "Parkir"), date: now, note: "   ", now: now)
        #expect(added.note == nil)
    }

    @Test(arguments: [Int64(0), -1, -25_000])
    func addRejectsNonPositiveAmounts(amount: Int64) throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        #expect(throws: TransactionError.amountNotPositive) {
            try ledger.addTransaction(amount: amount, subcategory: makan, date: now, note: nil, now: now)
        }
        #expect(try savedTransactions(store).isEmpty)
        #expect(!store.context.hasChanges, "a rejected add leaves nothing pending")
    }

    @Test func addRejectsAHiddenSubcategory() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        kopi.isHidden = true
        try store.context.save()
        #expect(throws: TransactionError.subcategoryHidden) {
            try ledger.addTransaction(amount: 20_000, subcategory: kopi, date: now, note: nil, now: now)
        }
        #expect(try savedTransactions(store).isEmpty)
    }

    /// Upcoming days of this month are fine (D-044); the next month is not.
    @Test func addAcceptsTheRestOfThisMonthOnly() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        try ledger.addTransaction(amount: 20_000, subcategory: makan, date: Fixtures.date(2026, 11, 30, 23, 59, 59), note: nil, now: now)
        try ledger.addTransaction(amount: 20_000, subcategory: makan, date: Fixtures.date(2026, 12, 1, 0).addingTimeInterval(-0.001), note: nil, now: now)
        #expect(throws: TransactionError.dateAfterCurrentMonth) {
            try ledger.addTransaction(amount: 20_000, subcategory: makan, date: Fixtures.date(2026, 12, 1, 0), note: nil, now: now)
        }
        #expect(try savedTransactions(store).count == 2)
        #expect(try ledger.summary(for: november).kebutuhan == 40_000, "planned entries count toward this month")
    }

    /// The month boundary follows the ledger's time zone.
    @Test func monthLimitFollowsTheTimeZone() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let makan = try store.subcategory(named: "Makan")
        // 30 Nov 20:00 in Los Angeles is already 1 Dec in Jakarta.
        let now = Fixtures.date(2026, 11, 30, 20, in: Fixtures.losAngeles)
        let date = Fixtures.date(2026, 12, 1, 9, in: Fixtures.jakarta) // still 30 Nov in Los Angeles
        let losAngeles = Ledger(context: store.context, timeZone: Fixtures.losAngeles)
        #expect(throws: TransactionError.dateAfterCurrentMonth) {
            // Jakarta 2 Dec 09:00 = 1 Dec 16:00 in Los Angeles: next month there.
            try losAngeles.addTransaction(amount: 1_000, subcategory: makan, date: date.addingTimeInterval(86_400), note: nil, now: now)
        }
        try losAngeles.addTransaction(amount: 1_000, subcategory: makan, date: date, note: nil, now: now)
    }

    @Test func decemberAllowsTheWholeOfDecemberOnly() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let december = Fixtures.date(2026, 12, 20)
        try ledger.addTransaction(amount: 1_000, subcategory: makan, date: Fixtures.date(2026, 12, 31, 23, 59, 59), note: nil, now: december)
        #expect(throws: TransactionError.dateAfterCurrentMonth) {
            try ledger.addTransaction(amount: 1_000, subcategory: makan, date: Fixtures.date(2027, 1, 1, 0), note: nil, now: december)
        }
    }

    /// New entries start at the D-017 raw window: 1 Nov 2025 00:00 in Nov 2026 (D-044).
    @Test func addRejectsDatesBeforeTheRawWindow() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        try ledger.addTransaction(amount: 1_000, subcategory: makan, date: Fixtures.date(2025, 11, 1, 0), note: nil, now: now)
        #expect(throws: TransactionError.dateBeforeRawWindow) {
            try ledger.addTransaction(amount: 1_000, subcategory: makan, date: Fixtures.date(2025, 10, 31, 23, 59, 59), note: nil, now: now)
        }
        #expect(throws: TransactionError.dateBeforeRawWindow) {
            try ledger.addTransaction(amount: 1_000, subcategory: makan, date: Fixtures.date(2024, 3, 1), note: nil, now: now)
        }
        #expect(try savedTransactions(store).count == 1)
        #expect(!store.context.hasChanges)
    }

    // MARK: - Update

    /// Saves a transaction directly, bypassing the ledger's date rules, as an older build or another
    /// time zone could have left it.
    private func insertDirectly(_ store: TestStore, amount: Int64, subcategory: Subcategory, date: Date) throws -> MoneyTransaction {
        let transaction = MoneyTransaction(amount: amount, subcategory: subcategory, date: date, createdAt: date)
        store.context.insert(transaction)
        try store.context.save()
        return transaction
    }

    /// An edit may keep a date older than the raw window (until Phase 8 purges it), but not go further back.
    @Test func updateMayKeepADateOlderThanTheWindow() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let old = Fixtures.date(2025, 10, 20, 8)
        let transaction = try insertDirectly(store, amount: 10_000, subcategory: makan, date: old)

        try ledger.updateTransaction(transaction, amount: 11_000, subcategory: makan, date: old, note: nil, now: now)
        #expect(try #require(try savedTransactions(store).first).date == old)

        #expect(throws: TransactionError.dateBeforeRawWindow) {
            try ledger.updateTransaction(transaction, amount: 11_000, subcategory: makan, date: Fixtures.date(2025, 10, 1), note: nil, now: now)
        }
        #expect(transaction.date == old)
    }

    /// An edit may keep a date after this month (recorded in a time zone ahead), but not go further ahead.
    @Test func updateMayKeepADateAfterThisMonth() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let ahead = Fixtures.date(2026, 12, 1, 6, 30)
        let transaction = try insertDirectly(store, amount: 10_000, subcategory: makan, date: ahead)

        try ledger.updateTransaction(transaction, amount: 12_000, subcategory: makan, date: ahead, note: "x", now: now)
        let saved = try #require(try savedTransactions(store).first)
        #expect(saved.date == ahead)
        #expect(saved.amount == 12_000)

        #expect(throws: TransactionError.dateAfterCurrentMonth) {
            try ledger.updateTransaction(transaction, amount: 12_000, subcategory: makan, date: Fixtures.date(2026, 12, 5), note: nil, now: now)
        }
        #expect(transaction.date == ahead)
    }

    @Test func updateChangesEveryEditableField() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let kopi = try store.subcategory(named: "Kopi")
        let transaction = try ledger.addTransaction(amount: 30_000, subcategory: makan, date: now, note: "siang", now: now)
        let newDate = Fixtures.date(2026, 11, 3, 19)

        try ledger.updateTransaction(transaction, amount: 42_000, subcategory: kopi, date: newDate, note: "", now: now)

        #expect(!store.context.hasChanges, "update saves the context")
        let saved = try #require(try savedTransactions(store).first)
        #expect(saved.amount == 42_000)
        #expect(saved.subcategoryID == kopi.id)
        #expect(saved.group == .keinginan)
        #expect(saved.date == newDate)
        #expect(saved.note == nil)
        #expect(try ledger.summary(for: november).keinginan == 42_000)
    }

    /// Kind follows the subcategory: moving an expense to an income subcategory makes it income.
    @Test func updateCanChangeTheKind() throws {
        let (store, ledger) = try makeStore()
        let transaction = try ledger.addTransaction(
            amount: 100_000, subcategory: try store.subcategory(named: "Makan"), date: now, note: nil, now: now
        )
        try ledger.updateTransaction(
            transaction, amount: 100_000, subcategory: try store.subcategory(named: "Refund"), date: now, note: nil, now: now
        )
        #expect(transaction.kind == .income)
        #expect(transaction.group == nil)
        let summary = try ledger.summary(for: november)
        #expect(summary.income == 100_000)
        #expect(summary.kebutuhan == 0)
    }

    @Test func updateRejectsInvalidInputAndChangesNothing() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let jajan = try store.subcategory(named: "Jajan")
        jajan.isHidden = true
        let transaction = try ledger.addTransaction(amount: 30_000, subcategory: makan, date: now, note: "a", now: now)

        #expect(throws: TransactionError.amountNotPositive) {
            try ledger.updateTransaction(transaction, amount: 0, subcategory: makan, date: now, note: "b", now: now)
        }
        #expect(throws: TransactionError.subcategoryHidden) {
            try ledger.updateTransaction(transaction, amount: 1_000, subcategory: jajan, date: now, note: "b", now: now)
        }
        #expect(throws: TransactionError.dateAfterCurrentMonth) {
            try ledger.updateTransaction(transaction, amount: 1_000, subcategory: makan, date: Fixtures.date(2026, 12, 2), note: "b", now: now)
        }
        #expect(transaction.amount == 30_000)
        #expect(transaction.subcategoryID == makan.id)
        #expect(transaction.date == now)
        #expect(transaction.note == "a")
    }

    /// A transaction already in a subcategory that was hidden later stays editable there.
    @Test func updateKeepsAnAlreadyHiddenSubcategory() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        let transaction = try ledger.addTransaction(amount: 18_000, subcategory: kopi, date: now, note: nil, now: now)
        kopi.isHidden = true
        try store.context.save()

        try ledger.updateTransaction(transaction, amount: 22_000, subcategory: kopi, date: now, note: nil, now: now)
        #expect(try #require(try savedTransactions(store).first).amount == 22_000)
    }

    // MARK: - Delete

    @Test func deleteRemovesOnlyThatTransaction() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let keep = try ledger.addTransaction(amount: 10_000, subcategory: makan, date: now, note: nil, now: now)
        let gone = try ledger.addTransaction(amount: 20_000, subcategory: makan, date: now, note: nil, now: now)

        try ledger.deleteTransaction(gone)

        #expect(!store.context.hasChanges, "delete saves the context")
        #expect(try savedTransactions(store).map(\.id) == [keep.id])
        // The subcategory stays.
        #expect(try store.subcategory(named: "Makan").id == makan.id)
    }

    @Test func deleteByID() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let transaction = try ledger.addTransaction(amount: 10_000, subcategory: makan, date: now, note: nil, now: now)
        #expect(try ledger.transaction(id: transaction.id)?.amount == 10_000)
        #expect(try ledger.deleteTransaction(id: transaction.id))
        #expect(try savedTransactions(store).isEmpty)
        #expect(try ledger.deleteTransaction(id: transaction.id) == false, "deleting twice is a no-op")
        #expect(try ledger.transaction(id: transaction.id) == nil)
    }

    // MARK: - Failed saves roll back (SwiftData can't be made to fail a real save reliably, so the save is swapped)

    private struct SaveFailed: Error {}

    private func failingLedger(_ store: TestStore) -> Ledger {
        Ledger(context: store.context, timeZone: Fixtures.jakarta) { _ in throw SaveFailed() }
    }

    @Test func failedAddLeavesNothingPending() throws {
        let (store, _) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        #expect(throws: SaveFailed.self) {
            try failingLedger(store).addTransaction(amount: 30_000, subcategory: makan, date: now, note: nil, now: now)
        }
        #expect(!store.context.hasChanges)
        #expect(try store.context.fetchCount(FetchDescriptor<MoneyTransaction>()) == 0, "no pending row to show or duplicate")
    }

    /// The retry after a failed add saves exactly one row. The failed row must not survive in the
    /// subcategory's inverse `transactions` array, or the retry's save would persist it too.
    @Test func retryAfterAFailedAddSavesExactlyOneRow() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        #expect(throws: SaveFailed.self) {
            try failingLedger(store).addTransaction(amount: 30_000, subcategory: makan, date: now, note: "siang", now: now)
        }
        #expect(makan.transactions.isEmpty, "the failed row is gone from the inverse relationship")

        let added = try ledger.addTransaction(amount: 30_000, subcategory: makan, date: now, note: "siang", now: now)

        let saved = try savedTransactions(store)
        #expect(saved.map(\.id) == [added.id], "exactly one row is saved: \(saved.count)")
        #expect(makan.transactions.map(\.id) == [added.id])
        let fresh = ModelContext(store.container)
        let makanID = makan.id
        let freshMakan = try #require(try fresh.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.id == makanID })).first)
        #expect(freshMakan.transactions.count == 1)
    }

    @Test func failedUpdateRestoresTheOldValues() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let kopi = try store.subcategory(named: "Kopi")
        let date = Fixtures.date(2026, 11, 10)
        let transaction = try ledger.addTransaction(amount: 30_000, subcategory: makan, date: date, note: "siang", now: now)

        #expect(throws: SaveFailed.self) {
            try failingLedger(store).updateTransaction(transaction, amount: 99_000, subcategory: kopi, date: now, note: "x", now: now)
        }
        #expect(!store.context.hasChanges)
        #expect(transaction.amount == 30_000)
        #expect(transaction.subcategoryID == makan.id)
        #expect(transaction.group == .kebutuhan)
        #expect(transaction.date == date)
        #expect(transaction.note == "siang")
        #expect(transaction.subcategory?.id == makan.id)
        #expect(makan.transactions.map(\.id) == [transaction.id], "back in the old subcategory's inverse array")
        #expect(kopi.transactions.isEmpty, "gone from the new subcategory's inverse array")

        // A later unrelated save must not persist the undone move.
        try ledger.addTransaction(amount: 1_000, subcategory: kopi, date: now, note: nil, now: now)
        let transactionID = transaction.id
        let fresh = ModelContext(store.container)
        let saved = try #require(try fresh.fetch(FetchDescriptor<MoneyTransaction>(predicate: #Predicate { $0.id == transactionID })).first)
        #expect(saved.amount == 30_000)
        #expect(saved.subcategoryID == makan.id)
        #expect(saved.subcategory?.id == makan.id)
    }

    /// An orphaned transaction (its subcategory deleted, D-006) whose update fails stays orphaned:
    /// a later unrelated save must not persist the undone move.
    @Test func failedUpdateOfAnOrphanRestoresIt() throws {
        let (store, ledger) = try makeStore()
        let galon = try store.subcategory(named: "Galon")
        let kopi = try store.subcategory(named: "Kopi")
        let transaction = try ledger.addTransaction(amount: 12_000, subcategory: galon, date: now, note: nil, now: now)
        store.context.delete(galon)
        try store.context.save()
        #expect(transaction.subcategory == nil, "deleting the subcategory nullifies the link")
        let orphanedID = transaction.subcategoryID

        #expect(throws: SaveFailed.self) {
            try failingLedger(store).updateTransaction(transaction, amount: 15_000, subcategory: kopi, date: now, note: nil, now: now)
        }
        #expect(!store.context.hasChanges)
        #expect(transaction.subcategory == nil)
        #expect(transaction.subcategoryID == orphanedID)
        #expect(transaction.group == .kebutuhan, "the copied group is Galon's, not Kopi's")
        #expect(transaction.amount == 12_000)
        #expect(kopi.transactions.isEmpty)

        try ledger.addTransaction(amount: 1_000, subcategory: kopi, date: now, note: nil, now: now)
        let transactionID = transaction.id
        let fresh = ModelContext(store.container)
        let saved = try #require(try fresh.fetch(FetchDescriptor<MoneyTransaction>(predicate: #Predicate { $0.id == transactionID })).first)
        #expect(saved.subcategory == nil, "still orphaned on disk")
        #expect(saved.subcategoryID == orphanedID)
        #expect(saved.amount == 12_000)
    }

    @Test func failedDeleteKeepsTheRow() throws {
        let (store, ledger) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        let transaction = try ledger.addTransaction(amount: 30_000, subcategory: makan, date: now, note: nil, now: now)

        #expect(throws: SaveFailed.self) {
            try failingLedger(store).deleteTransaction(transaction)
        }
        #expect(!store.context.hasChanges)
        #expect(try ledger.transactions(in: november).map(\.id) == [transaction.id], "the row is back in the list fetch")
    }
}
