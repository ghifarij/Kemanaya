import Foundation

/// A plain, `Sendable` copy of a ``MoneyTransaction``: what aggregation needs, with no SwiftData attached.
public struct TransactionSnapshot: Hashable, Sendable {
    /// ``MoneyTransaction/id``.
    public var id: UUID
    /// Rupiah, > 0 (D-016).
    public var amount: Int64
    public var kind: TransactionKind
    /// Nil for income (D-005).
    public var group: ExpenseGroup?
    public var subcategoryID: UUID
    public var date: Date

    public init(id: UUID = UUID(), amount: Int64, kind: TransactionKind, group: ExpenseGroup?, subcategoryID: UUID, date: Date) {
        self.id = id
        self.amount = amount
        self.kind = kind
        self.group = group
        self.subcategoryID = subcategoryID
        self.date = date
    }

    public init(_ transaction: MoneyTransaction) {
        self.init(
            id: transaction.id,
            amount: transaction.amount,
            kind: transaction.kind,
            group: transaction.group,
            subcategoryID: transaction.subcategoryID,
            date: transaction.date
        )
    }
}
