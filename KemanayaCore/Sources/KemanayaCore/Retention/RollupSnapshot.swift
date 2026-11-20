import Foundation
import SwiftData

/// A plain, `Sendable` copy of a ``MonthlyRollup``: one subcategory's total for one purged month (D-017),
/// with the name and emoji it had when the month was rolled up.
public struct RollupSnapshot: Hashable, Sendable {
    public var month: MonthKey
    public var subcategoryID: UUID
    public var kind: TransactionKind
    /// Nil for income (D-005).
    public var group: ExpenseGroup?
    /// Rupiah (D-016).
    public var total: Int64
    /// Number of transactions summed.
    public var count: Int
    /// The subcategory's name when the month was rolled up; empty when it was already gone.
    public var name: String
    /// The subcategory's emoji when the month was rolled up; empty when it was already gone.
    public var emoji: String

    public init(
        month: MonthKey,
        subcategoryID: UUID,
        kind: TransactionKind,
        group: ExpenseGroup?,
        total: Int64,
        count: Int,
        name: String = "",
        emoji: String = ""
    ) {
        self.month = month
        self.subcategoryID = subcategoryID
        self.kind = kind
        self.group = group
        self.total = total
        self.count = count
        self.name = name
        self.emoji = emoji
    }

    /// Nil when the stored `monthKey` isn't a valid `yyyymm`, which only corrupt data could hold.
    public init?(_ rollup: MonthlyRollup) {
        guard let month = rollup.month else { return nil }
        self.init(
            month: month,
            subcategoryID: rollup.subcategoryID,
            kind: rollup.kind,
            group: rollup.group,
            total: rollup.total,
            count: rollup.count,
            name: rollup.name,
            emoji: rollup.emoji
        )
    }
}

extension MonthlyRollup {
    /// Rollups of the months `first` through `last`, both inclusive. Uses the `monthKey` index.
    /// Also usable in a view's `@Query`.
    public static func predicate(from first: MonthKey, through last: MonthKey) -> Predicate<MonthlyRollup> {
        let lower = first.rawValue
        let upper = last.rawValue
        return #Predicate { $0.monthKey >= lower && $0.monthKey <= upper }
    }

    /// One subcategory's rollup for `month` (at most one, by the unique constraint).
    public static func predicate(in month: MonthKey, subcategoryID: UUID) -> Predicate<MonthlyRollup> {
        let key = month.rawValue
        return #Predicate { $0.monthKey == key && $0.subcategoryID == subcategoryID }
    }

    /// A fetch for ``predicate(from:through:)``, oldest month first.
    public static func descriptor(from first: MonthKey, through last: MonthKey) -> FetchDescriptor<MonthlyRollup> {
        FetchDescriptor(predicate: predicate(from: first, through: last), sortBy: [SortDescriptor(\.monthKey)])
    }

    /// The rollup of the oldest month, if any: with ``MoneyTransaction/earliestDescriptor`` it tells
    /// where the yearly recap's years start (D-059).
    public static var earliestDescriptor: FetchDescriptor<MonthlyRollup> {
        var descriptor = FetchDescriptor<MonthlyRollup>(sortBy: [SortDescriptor(\.monthKey)])
        descriptor.fetchLimit = 1
        return descriptor
    }
}

extension MoneyTransaction {
    /// The oldest transaction, if any. One indexed row (D-018).
    public static var earliestDescriptor: FetchDescriptor<MoneyTransaction> {
        var descriptor = FetchDescriptor<MoneyTransaction>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }
}
