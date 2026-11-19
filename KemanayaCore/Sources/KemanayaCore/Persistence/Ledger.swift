import Foundation
import SwiftData

/// Read and write access to transactions and subcategories over one `ModelContext`.
/// Writes (add / update / delete) live in `Ledger+Writes.swift`.
///
/// Every transaction fetch is bounded by a month's date range (D-018), never the whole table.
/// Not `Sendable`: create it where the context lives and pass ``TransactionSnapshot``s or
/// ``MonthSummary`` values across actors instead of models.
public struct Ledger {
    /// Internal so the extensions in other files can reach it; callers keep their own reference.
    let context: ModelContext
    /// Months are bucketed in this zone, always on the Gregorian calendar (see ``MonthKey``).
    public let timeZone: TimeZone
    /// Saves `context`. Always `ModelContext.save()` in the app; tests swap in a failing save,
    /// because SwiftData has no reliable way to make a real save fail (unique attributes upsert).
    let save: (ModelContext) throws -> Void

    /// - Parameter timeZone: the app passes `.autoupdatingCurrent` (device-local, D-017).
    public init(context: ModelContext, timeZone: TimeZone) {
        self.init(context: context, timeZone: timeZone) { try $0.save() }
    }

    /// For tests: a ledger whose writes save through `save`.
    init(context: ModelContext, timeZone: TimeZone, save: @escaping (ModelContext) throws -> Void) {
        self.context = context
        self.timeZone = timeZone
        self.save = save
    }

    /// The month's transactions matching `filter`, newest first.
    public func transactions(in month: MonthKey, filter: TransactionFilter = .all) throws -> [MoneyTransaction] {
        try context.fetch(MoneyTransaction.descriptor(in: month.dateRange(in: timeZone), filter: filter))
    }

    /// The month's transactions as plain values, newest first.
    public func snapshots(in month: MonthKey, filter: TransactionFilter = .all) throws -> [TransactionSnapshot] {
        try transactions(in: month, filter: filter).map(TransactionSnapshot.init)
    }

    /// Totals, sisa and savings rate for the month (D-009).
    public func summary(for month: MonthKey) throws -> MonthSummary {
        try MonthSummary(snapshots(in: month))
    }

    /// The transaction with `id`, or nil when there is none (e.g. it was just deleted).
    public func transaction(id: UUID) throws -> MoneyTransaction? {
        var descriptor = FetchDescriptor<MoneyTransaction>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Pinned subcategories in Home order (D-012). All of them are visible: hiding unpins (D-049).
    public func pinnedSubcategories() throws -> [Subcategory] {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.pinOrder != nil },
            sortBy: [SortDescriptor(\.pinOrder)]
        )
        return try context.fetch(descriptor)
    }

    /// Monthly budgets of expense subcategories that have one, keyed by subcategory id (D-041).
    /// Hidden subcategories are included: their budget still applies to spending already logged.
    public func subcategoryBudgets() throws -> [UUID: Int64] {
        let expense = TransactionKind.expense.rawValue
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.monthlyBudget != nil && $0.kindRaw == expense }
        )
        return try context.fetch(descriptor).reduce(into: [:]) { result, subcategory in
            result[subcategory.id] = subcategory.monthlyBudget
        }
    }

    /// The add sheet's subcategory grid for `kind` (D-043): visible subcategories, each section by
    /// `sortOrder` (ties by name). Expenses come as a Kebutuhan section then a Keinginan section;
    /// income as one flat section. Empty sections are left out.
    ///
    /// - Parameter includedID: a subcategory to show even if hidden, e.g. the one of the transaction
    ///   being edited, so an edit never silently moves it. Ignored when it is of another kind.
    public func gridSections(for kind: TransactionKind, including includedID: UUID? = nil) throws -> [SubcategorySection] {
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.kindRaw == kindRaw },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        // At most a few dozen rows per kind, so the hidden filter runs in memory.
        let visible = try context.fetch(descriptor).filter { !$0.isHidden || $0.id == includedID }
        return SubcategorySection.sections(from: visible, kinds: [kind])
    }
}
