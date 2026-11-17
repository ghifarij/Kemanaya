import Foundation
import SwiftData

extension KemanayaSchemaV1 {
    /// One expense or income entry. Named `MoneyTransaction` because `Transaction` collides with `SwiftUI.Transaction`.
    ///
    /// `kindRaw`, `groupRaw` and `subcategoryID` are copied from the subcategory on purpose. Screens fetch
    /// "this date range, this kind or group" (D-014, D-018), and `#Predicate` translates plain stored
    /// columns reliably, while key paths through the optional `subcategory` relationship do not.
    /// The copies can't go stale: a subcategory's kind and group never change (D-004), and
    /// ``move(to:)`` is the only way to change the subcategory. They also keep an orphaned
    /// transaction countable if its subcategory is ever deleted.
    @Model
    public final class MoneyTransaction {
        #Index<MoneyTransaction>([\.date])

        /// Stable across edits, backups and restores (D-019).
        @Attribute(.unique) public private(set) var id: UUID
        /// Rupiah, always > 0 (D-016). `kind` says which direction the money went. Change it with ``setAmount(_:)``.
        public private(set) var amount: Int64
        /// The day the money moved; defaults to now (D-013). Indexed (D-018).
        public var date: Date
        /// Optional. Blank notes are stored as nil; set it through ``setNote(_:)`` to keep that true.
        public private(set) var note: String?
        public private(set) var createdAt: Date

        /// Nil only if the subcategory was deleted, which the app avoids (D-006).
        public private(set) var subcategory: Subcategory?
        /// Copy of `subcategory.id`.
        public private(set) var subcategoryID: UUID
        /// Copy of `subcategory.kindRaw`.
        public private(set) var kindRaw: String
        /// Copy of `subcategory.groupRaw`.
        public private(set) var groupRaw: String?

        /// - Parameter id: pass one only when restoring a transaction (D-019).
        /// - Precondition: `amount > 0` (D-016).
        public init(
            id: UUID = UUID(),
            amount: Int64,
            subcategory: Subcategory,
            date: Date = .now,
            note: String? = nil,
            createdAt: Date = .now
        ) {
            precondition(amount > 0, "amounts are positive rupiah; kind carries the direction")
            self.id = id
            self.amount = amount
            self.date = date
            self.note = Self.normalized(note)
            self.createdAt = createdAt
            self.subcategory = subcategory
            self.subcategoryID = subcategory.id
            self.kindRaw = subcategory.kindRaw
            self.groupRaw = subcategory.groupRaw
        }

        /// Moves this transaction to another subcategory and refreshes the copied fields.
        public func move(to subcategory: Subcategory) {
            self.subcategory = subcategory
            subcategoryID = subcategory.id
            kindRaw = subcategory.kindRaw
            groupRaw = subcategory.groupRaw
        }

        /// - Precondition: `amount > 0` (D-016).
        public func setAmount(_ amount: Int64) {
            precondition(amount > 0, "amounts are positive rupiah; kind carries the direction")
            self.amount = amount
        }

        /// Sets the note; blank or whitespace-only text clears it.
        public func setNote(_ note: String?) {
            self.note = Self.normalized(note)
        }

        public var kind: TransactionKind {
            TransactionKind(rawValue: kindRaw) ?? .expense
        }

        public var group: ExpenseGroup? {
            groupRaw.flatMap(ExpenseGroup.init(rawValue:))
        }

        private static func normalized(_ note: String?) -> String? {
            guard let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return note
        }
    }
}
