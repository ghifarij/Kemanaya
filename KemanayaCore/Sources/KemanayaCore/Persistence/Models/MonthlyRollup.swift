import Foundation
import SwiftData

extension KemanayaSchemaV1 {
    /// One subcategory's total for one month, kept forever after the raw transactions are purged (D-017).
    ///
    /// Name, emoji, kind and group are snapshots taken when the month is rolled up, so recaps still read
    /// right after the subcategory is renamed or hidden. Rollup and purge logic arrive in Phase 8.
    @Model
    public final class MonthlyRollup {
        #Unique<MonthlyRollup>([\.monthKey, \.subcategoryID])
        #Index<MonthlyRollup>([\.monthKey])

        /// ``MonthKey/rawValue``, `yyyymm`.
        public private(set) var monthKey: Int
        public private(set) var subcategoryID: UUID
        /// Sum of the month's amounts in rupiah (D-016).
        public var total: Int64
        /// Number of transactions summed.
        public var count: Int
        public var name: String
        public var emoji: String
        public private(set) var kindRaw: String
        public private(set) var groupRaw: String?

        public init(
            month: MonthKey,
            subcategoryID: UUID,
            total: Int64,
            count: Int,
            name: String,
            emoji: String,
            kind: TransactionKind,
            group: ExpenseGroup?
        ) {
            self.monthKey = month.rawValue
            self.subcategoryID = subcategoryID
            self.total = total
            self.count = count
            self.name = name
            self.emoji = emoji
            self.kindRaw = kind.rawValue
            self.groupRaw = group?.rawValue
        }

        public var month: MonthKey? { MonthKey(rawValue: monthKey) }

        public var kind: TransactionKind {
            TransactionKind(rawValue: kindRaw) ?? .expense
        }

        public var group: ExpenseGroup? {
            groupRaw.flatMap(ExpenseGroup.init(rawValue:))
        }
    }
}
