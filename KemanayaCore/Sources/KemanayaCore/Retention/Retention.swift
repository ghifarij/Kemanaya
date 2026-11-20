import Foundation
import SwiftData

/// What one retention run did, for logs and tests.
public struct RetentionReport: Equatable, Sendable {
    /// The months rolled up and purged, oldest first. Empty when nothing was older than the window.
    public let rolledUpMonths: [MonthKey]
    /// Raw transactions deleted after being added into rollups.
    public let purgedTransactionCount: Int
    /// The context had unsaved changes, so the run didn't start (see ``Retention``); the next one will.
    public let skippedForPendingChanges: Bool

    public init(rolledUpMonths: [MonthKey], purgedTransactionCount: Int, skippedForPendingChanges: Bool = false) {
        self.rolledUpMonths = rolledUpMonths
        self.purgedTransactionCount = purgedTransactionCount
        self.skippedForPendingChanges = skippedForPendingChanges
    }

    /// Nothing was older than the raw window: the run changed nothing.
    public var isEmpty: Bool { rolledUpMonths.isEmpty }
}

/// Rolling retention (D-017, D-059): raw transactions are kept for this month and the 12 before it; each
/// older month is rolled up into permanent ``MonthlyRollup`` rows, then its raw transactions are deleted.
///
/// - **Cheap when there is nothing to do:** the check is one fetch of a single row by the `date` index
///   (D-018), so the app runs it on every launch and foreground without storing a "last run" month.
/// - **One month per save:** the oldest month with raw transactions is rolled up and its transactions
///   deleted in a single save, so a crash leaves the month either all raw or all rolled up, never half.
///   Then the next oldest, until nothing is older than the window: an app left closed for months catches up.
/// - **Adds, never replaces:** when a rollup for that (month, subcategory) already exists (e.g. after a
///   restore, D-060), the month's totals are added into it and its name and emoji snapshots refreshed.
/// - **Idempotent:** a second run in the same month finds nothing older than the window and does nothing.
/// - **Never touches pending changes:** when the context has unsaved changes (an edit in progress
///   elsewhere), the run is skipped. Saving them would commit something the user hasn't confirmed, and a
///   failed month's `rollback()` would throw them away. Retention runs again on the next launch,
///   foreground or month change, so skipping loses nothing.
/// - **Sums clamp** at `Int64`'s limit instead of trapping (amounts are capped by ``AmountEntry/maximum``,
///   so real data never gets near it).
public enum Retention {
    /// Rolls up and purges every month before the raw window, oldest first, one save per month.
    ///
    /// - Parameters:
    ///   - now: the clock; the window is ``RetentionWindow/rawWindowStart(now:timeZone:)``.
    ///   - timeZone: the device zone (D-017); the app passes `.autoupdatingCurrent`.
    /// - Throws: the save error of the month that failed. That month is rolled back (nothing half-applied
    ///   lingers) and the months before it stay rolled up; the next run carries on from there.
    @discardableResult
    public static func run(in context: ModelContext, now: Date = .now, timeZone: TimeZone) throws -> RetentionReport {
        try run(in: context, now: now, timeZone: timeZone) { try $0.save() }
    }

    /// For tests: a run whose saves go through `save`, so a failing save can be simulated.
    static func run(
        in context: ModelContext,
        now: Date,
        timeZone: TimeZone,
        save: (ModelContext) throws -> Void
    ) throws -> RetentionReport {
        guard !context.hasChanges else {
            return RetentionReport(rolledUpMonths: [], purgedTransactionCount: 0, skippedForPendingChanges: true)
        }
        let windowStart = RetentionWindow.rawWindowStart(now: now, timeZone: timeZone)
        var months: [MonthKey] = []
        var purged = 0
        while let oldest = try oldestDate(before: windowStart, in: context) {
            // Before the window's first instant, so the whole month is before the window too.
            let month = MonthKey(containing: oldest, timeZone: timeZone)
            // Each pass deletes the month it found, so a month seen twice means the delete didn't stick.
            // Stop instead of looping forever.
            if let last = months.last, month <= last { throw RetentionError.noProgress(month) }
            purged += try rollUp(month, in: context, timeZone: timeZone, save: save)
            months.append(month)
        }
        return RetentionReport(rolledUpMonths: months, purgedTransactionCount: purged)
    }

    /// The date of the oldest transaction before `windowStart`, if any: one row by the `date` index.
    private static func oldestDate(before windowStart: Date, in context: ModelContext) throws -> Date? {
        var descriptor = FetchDescriptor<MoneyTransaction>(
            predicate: #Predicate { $0.date < windowStart },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.date
    }

    /// Adds `month`'s transactions into its rollups, deletes them, and saves once.
    /// - Returns: how many transactions were purged.
    private static func rollUp(
        _ month: MonthKey,
        in context: ModelContext,
        timeZone: TimeZone,
        save: (ModelContext) throws -> Void
    ) throws -> Int {
        let transactions = try context.fetch(FetchDescriptor(predicate: MoneyTransaction.predicate(in: month.dateRange(in: timeZone))))
        let monthKey = month.rawValue
        let existing = try context.fetch(FetchDescriptor<MonthlyRollup>(predicate: #Predicate { $0.monthKey == monthKey }))
        // The unique constraint allows one per subcategory; should duplicates ever exist, the first wins.
        let rollups = Dictionary(existing.map { ($0.subcategoryID, $0) }, uniquingKeysWith: { first, _ in first })

        // Old values of the rollups this month changes: `rollback()` doesn't revert attributes of saved models.
        var restores: [() -> Void] = []
        let bySubcategory = Dictionary(grouping: transactions, by: \.subcategoryID)
        for (subcategoryID, entries) in bySubcategory.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            let total = entries.lazy.map(\.amount).saturatingSum()
            // Any entry's subcategory: they share the id. Nil only for orphans (D-006).
            let subcategory = entries.lazy.compactMap(\.subcategory).first
            if let rollup = rollups[subcategoryID] {
                let old = (total: rollup.total, count: rollup.count, name: rollup.name, emoji: rollup.emoji)
                restores.append {
                    rollup.total = old.total
                    rollup.count = old.count
                    rollup.name = old.name
                    rollup.emoji = old.emoji
                }
                rollup.total = rollup.total.saturatingAdding(total)
                rollup.count += entries.count
                if let subcategory {
                    rollup.name = subcategory.name
                    rollup.emoji = subcategory.emoji
                }
            } else {
                let first = entries[0]
                context.insert(MonthlyRollup(
                    month: month,
                    subcategoryID: subcategoryID,
                    total: total,
                    count: entries.count,
                    name: subcategory?.name ?? "",
                    emoji: subcategory?.emoji ?? "",
                    kind: first.kind,
                    group: first.group
                ))
            }
        }
        for transaction in transactions {
            context.delete(transaction)
        }
        do {
            try save(context)
        } catch {
            for restore in restores { restore() }
            context.rollback()
            throw error
        }
        return transactions.count
    }
}

/// Why a retention run stopped.
public enum RetentionError: Error, Equatable {
    /// The month was rolled up and saved, yet transactions of it (or an older month) were still found.
    /// The run stops rather than loop forever or add the same month into its rollups twice.
    case noProgress(MonthKey)
}
