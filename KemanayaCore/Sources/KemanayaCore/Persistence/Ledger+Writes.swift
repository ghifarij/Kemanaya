import Foundation
import SwiftData

/// Add, update and delete (D-013, D-043, D-044). Every write validates first, changes the context,
/// then saves, so `@Query` views refresh at once.
///
/// - A rejected write (``TransactionError``) changes nothing.
/// - A failed save **rolls the context back** and rethrows SwiftData's error, so nothing half-applied
///   lingers: a failed add leaves no pending row (no duplicate on retry), a failed update restores the
///   model's old values, and a failed delete brings the row back. Rollback discards *every* pending
///   change in the context; the app's writes always save at once, so there are none of its own.
///   SwiftData's `rollback()` drops pending inserts and deletes but reverts neither attribute values nor
///   inverse relationship arrays of already-saved models. So before rolling back, an update puts the old
///   values and placement back itself, and a failed add unlinks its row from the subcategory, whose
///   `transactions` array would otherwise keep the discarded row.
extension Ledger {
    /// Adds and saves a transaction. Its kind and group come from `subcategory` (D-004).
    ///
    /// - Parameters:
    ///   - date: when the money moved; callers resolve it with ``AddDraft/dateToSave(now:timeZone:)``.
    ///   - note: trimmed; blank becomes nil.
    ///   - now: the clock, injectable for tests. `date` must be in ``RetentionWindow/entryDates(now:timeZone:keeping:)``:
    ///     not before the D-017 raw window, not in a later month (D-044).
    /// - Throws: ``TransactionError`` when `amount ≤ 0`, `subcategory` is hidden, or `date` is outside the
    ///   entry dates (in ``timeZone``); otherwise the save error.
    @discardableResult
    public func addTransaction(
        amount: Int64,
        subcategory: Subcategory,
        date: Date,
        note: String?,
        now: Date = .now
    ) throws -> MoneyTransaction {
        try validate(amount: amount, date: date, now: now, keeping: nil)
        guard !subcategory.isHidden else { throw TransactionError.subcategoryHidden }
        let transaction = MoneyTransaction(amount: amount, subcategory: subcategory, date: date, note: Self.trimmed(note), createdAt: now)
        context.insert(transaction)
        try saveOrRollBack { transaction.detachFromSubcategory() }
        return transaction
    }

    /// Replaces every editable field of `transaction` and saves. Moving it to a subcategory of the
    /// other kind changes its kind too (``MoneyTransaction/move(to:)``).
    ///
    /// The entry dates widen to include the transaction's current date, so an edit may keep a date that is
    /// older than the raw window or after this month (``RetentionWindow/entryDates(now:timeZone:keeping:)``).
    ///
    /// - Throws: ``TransactionError`` when `amount ≤ 0`, `date` is outside those entry dates, or `subcategory`
    ///   is a *different* subcategory that is hidden (staying in an already-hidden one is fine); otherwise the save error.
    public func updateTransaction(
        _ transaction: MoneyTransaction,
        amount: Int64,
        subcategory: Subcategory,
        date: Date,
        note: String?,
        now: Date = .now
    ) throws {
        try validate(amount: amount, date: date, now: now, keeping: transaction.date)
        let isMove = subcategory.id != transaction.subcategoryID
        if isMove, subcategory.isHidden { throw TransactionError.subcategoryHidden }
        let old = (amount: transaction.amount, placement: transaction.placement, date: transaction.date, note: transaction.note)
        transaction.setAmount(amount)
        if isMove { transaction.move(to: subcategory) }
        transaction.date = date
        transaction.setNote(Self.trimmed(note))
        try saveOrRollBack {
            transaction.setAmount(old.amount)
            transaction.restore(old.placement) // also an orphan's nil subcategory, which move(to:) can't express
            transaction.date = old.date
            transaction.setNote(old.note)
        }
    }

    /// Deletes `transaction` and saves. The confirmation (D-043) is the caller's job.
    public func deleteTransaction(_ transaction: MoneyTransaction) throws {
        context.delete(transaction)
        try saveOrRollBack()
    }

    /// Deletes the transaction with `id`, if it still exists, and saves.
    /// - Returns: false when there was nothing to delete.
    @discardableResult
    public func deleteTransaction(id: UUID) throws -> Bool {
        guard let transaction = try transaction(id: id) else { return false }
        try deleteTransaction(transaction)
        return true
    }

    /// - Parameter existing: the edited transaction's current date, which the allowed dates widen to keep.
    private func validate(amount: Int64, date: Date, now: Date, keeping existing: Date?) throws(TransactionError) {
        guard amount > 0 else { throw .amountNotPositive }
        let allowed = RetentionWindow.entryDates(now: now, timeZone: timeZone, keeping: existing)
        guard date <= allowed.upperBound else { throw .dateAfterCurrentMonth }
        guard date >= allowed.lowerBound else { throw .dateBeforeRawWindow }
    }

    /// Saves; on failure runs `restore` (puts changed values and relationships back), rolls back and rethrows.
    /// Internal so the pin writes (`Ledger+Pins.swift`) follow the same discipline.
    func saveOrRollBack(restoring restore: () -> Void = {}) throws {
        do {
            try save(context)
        } catch {
            restore()
            context.rollback()
            throw error
        }
    }

    private static func trimmed(_ note: String?) -> String? {
        note?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
