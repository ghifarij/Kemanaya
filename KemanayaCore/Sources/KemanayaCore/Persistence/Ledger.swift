import Foundation
import SwiftData

/// Read access to transactions and subcategories over one `ModelContext`.
///
/// Every transaction fetch is bounded by a month's date range (D-018), never the whole table.
/// Not `Sendable`: create it where the context lives and pass ``TransactionSnapshot``s or
/// ``MonthSummary`` values across actors instead of models.
public struct Ledger {
    private let context: ModelContext
    /// Months are bucketed in this zone, always on the Gregorian calendar (see ``MonthKey``).
    public let timeZone: TimeZone

    /// - Parameter timeZone: the app passes `.autoupdatingCurrent` (device-local, D-017).
    public init(context: ModelContext, timeZone: TimeZone) {
        self.context = context
        self.timeZone = timeZone
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

    /// Pinned, visible subcategories in Home order (D-012).
    public func pinnedSubcategories() throws -> [Subcategory] {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.pinOrder != nil && !$0.isHidden },
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
}
