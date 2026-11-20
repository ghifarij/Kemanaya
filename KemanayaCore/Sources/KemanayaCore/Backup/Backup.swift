import Foundation
import SwiftData

/// Backup and restore over a `ModelContext` (D-019, D-060). The file format is ``BackupDocument``.
///
/// These are the only reads of whole tables: a backup holds everything, so it can't be bounded by a
/// month (D-018 applies to screens).
public enum Backup {
    // MARK: - Snapshot

    /// Everything in the store as a normalized ``BackupDocument``. Reads only: it never inserts the
    /// settings row (a store without one backs up the defaults).
    ///
    /// - Parameters:
    ///   - exportedAt: the clock, recorded in the file.
    ///   - appVersion: the app's marketing version, e.g. `1.0`.
    public static func snapshot(of context: ModelContext, exportedAt: Date = .now, appVersion: String) throws -> BackupDocument {
        let subcategories = try context.fetch(FetchDescriptor<Subcategory>()).map { subcategory in
            BackupDocument.SubcategoryRecord(
                id: subcategory.id,
                name: subcategory.name,
                emoji: subcategory.emoji,
                kind: subcategory.kind,
                group: subcategory.group,
                sortOrder: subcategory.sortOrder,
                isHidden: subcategory.isHidden,
                pinOrder: subcategory.pinOrder,
                monthlyBudget: subcategory.monthlyBudget,
                createdAt: subcategory.createdAt
            )
        }
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>()).map { transaction in
            BackupDocument.TransactionRecord(
                id: transaction.id,
                amount: transaction.amount,
                date: transaction.date,
                note: transaction.note,
                createdAt: transaction.createdAt,
                subcategoryID: transaction.subcategoryID,
                kind: transaction.kind,
                group: transaction.group
            )
        }
        let rollups = try context.fetch(FetchDescriptor<MonthlyRollup>()).map { rollup in
            BackupDocument.RollupRecord(
                monthKey: rollup.monthKey,
                subcategoryID: rollup.subcategoryID,
                total: rollup.total,
                count: rollup.count,
                name: rollup.name,
                emoji: rollup.emoji,
                kind: rollup.kind,
                group: rollup.group
            )
        }
        let settings = try currentSettings(in: context).map { settings in
            BackupDocument.SettingsRecord(
                kebutuhanBudget: settings.budget(for: .kebutuhan),
                keinginanBudget: settings.budget(for: .keinginan),
                seedVersion: settings.seedVersion
            )
        } ?? BackupDocument.SettingsRecord(kebutuhanBudget: nil, keinginanBudget: nil, seedVersion: 0)
        return BackupDocument(
            exportedAt: exportedAt,
            appVersion: appVersion,
            subcategories: subcategories,
            transactions: transactions,
            rollups: rollups,
            settings: settings
        ).normalized()
    }

    /// The settings row ``AppSettings/fetchOrCreate(in:)`` would pick, without inserting one.
    private static func currentSettings(in context: ModelContext) throws -> AppSettings? {
        var descriptor = FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.seedVersion, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Fresh install

    /// At most one transaction, any date: whether there is any. Home queries it live (D-060).
    public static var anyTransaction: FetchDescriptor<MoneyTransaction> {
        var descriptor = FetchDescriptor<MoneyTransaction>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// At most one rollup: whether there is any.
    public static var anyRollup: FetchDescriptor<MonthlyRollup> {
        var descriptor = FetchDescriptor<MonthlyRollup>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    /// A fresh install (Phase 3 note a, D-060): no transactions and no rollups. The seed's subcategories
    /// and settings don't count, so a store that only has the seed is fresh.
    public static func isFreshInstall(_ context: ModelContext) throws -> Bool {
        try context.fetch(anyTransaction).isEmpty && context.fetch(anyRollup).isEmpty
    }

    // MARK: - Restore

    /// Replaces everything in the store with `document` in **one save** (D-060): every transaction,
    /// rollup, subcategory and settings row is deleted and the backup's are inserted.
    ///
    /// The document is validated first (``BackupDocument/validate()``), so a bad one changes nothing. If
    /// the save fails, the context is rolled back: the deletes and inserts are discarded together and the
    /// old data stays. The caller runs retention afterwards (D-059), because an old backup can hold months
    /// that are now before the raw window.
    ///
    /// - Throws: ``BackupError`` for an invalid document, otherwise the save error.
    public static func restore(_ document: BackupDocument, into context: ModelContext) throws {
        try restore(document, into: context) { try $0.save() }
    }

    /// For tests: a restore whose save goes through `save`, so a failing save can be simulated.
    static func restore(_ document: BackupDocument, into context: ModelContext, save: (ModelContext) throws -> Void) throws {
        try document.validate()
        // Nothing of the app's own may be pending: rollback() below would discard it with the restore.
        if context.hasChanges { try save(context) }

        for transaction in try context.fetch(FetchDescriptor<MoneyTransaction>()) { context.delete(transaction) }
        for rollup in try context.fetch(FetchDescriptor<MonthlyRollup>()) { context.delete(rollup) }
        for subcategory in try context.fetch(FetchDescriptor<Subcategory>()) { context.delete(subcategory) }
        for settings in try context.fetch(FetchDescriptor<AppSettings>()) { context.delete(settings) }

        var subcategories: [UUID: Subcategory] = [:]
        for record in document.subcategories {
            let subcategory = Subcategory(
                id: record.id,
                name: record.name,
                emoji: record.emoji,
                kind: record.kind,
                group: record.group,
                sortOrder: record.sortOrder,
                isHidden: record.isHidden,
                pinOrder: record.pinOrder,
                createdAt: record.createdAt
            )
            // Validated: only expenses carry a budget, and it is positive.
            try? subcategory.setMonthlyBudget(record.monthlyBudget)
            context.insert(subcategory)
            subcategories[record.id] = subcategory
        }
        for record in document.transactions {
            context.insert(MoneyTransaction(
                restoringID: record.id,
                amount: record.amount,
                date: record.date,
                note: record.note,
                createdAt: record.createdAt,
                subcategory: subcategories[record.subcategoryID],
                subcategoryID: record.subcategoryID,
                kindRaw: record.kind.rawValue,
                groupRaw: record.group?.rawValue
            ))
        }
        for record in document.rollups {
            context.insert(MonthlyRollup(
                // Validated: a real `yyyymm`.
                month: MonthKey(rawValue: record.monthKey)!,
                subcategoryID: record.subcategoryID,
                total: record.total,
                count: record.count,
                name: record.name,
                emoji: record.emoji,
                kind: record.kind,
                group: record.group
            ))
        }
        let settings = AppSettings(seedVersion: document.settings.seedVersion)
        settings.setBudget(document.settings.kebutuhanBudget, for: .kebutuhan)
        settings.setBudget(document.settings.keinginanBudget, for: .keinginan)
        context.insert(settings)

        do {
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
