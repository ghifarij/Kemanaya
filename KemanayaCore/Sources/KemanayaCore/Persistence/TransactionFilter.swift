import Foundation
import SwiftData

/// Which transactions of a date range to fetch.
public enum TransactionFilter: Hashable, Sendable {
    /// Expenses and income.
    case all
    /// One kind: all expenses or all income.
    case kind(TransactionKind)
    /// Expenses of one group (D-003).
    case group(ExpenseGroup)
    /// One subcategory's transactions, e.g. its detail screen (D-051).
    case subcategory(UUID)
}

extension MoneyTransaction {
    /// Transactions dated in `range` (`lowerBound` inclusive, `upperBound` exclusive) that match `filter`.
    /// Uses only stored columns, so SwiftData translates it to SQL and the `date` index applies (D-018).
    /// Also usable in a view's `@Query`.
    public static func predicate(in range: Range<Date>, filter: TransactionFilter = .all) -> Predicate<MoneyTransaction> {
        let start = range.lowerBound
        let end = range.upperBound
        switch filter {
        case .all:
            return #Predicate { $0.date >= start && $0.date < end }
        case .kind(let kind):
            let kindRaw = kind.rawValue
            return #Predicate { $0.date >= start && $0.date < end && $0.kindRaw == kindRaw }
        case .group(let group):
            let groupRaw: String? = group.rawValue
            return #Predicate { $0.date >= start && $0.date < end && $0.groupRaw == groupRaw }
        case .subcategory(let id):
            return #Predicate { $0.date >= start && $0.date < end && $0.subcategoryID == id }
        }
    }

    /// A fetch for ``predicate(in:filter:)``, newest first (ties: newest entry first).
    public static func descriptor(in range: Range<Date>, filter: TransactionFilter = .all) -> FetchDescriptor<MoneyTransaction> {
        FetchDescriptor(
            predicate: predicate(in: range, filter: filter),
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
    }
}
