import Foundation
import SwiftData

extension KemanayaSchemaV1 {
    /// A user-editable bucket such as Makan 🍚 or Gaji 💼 (D-006, D-007).
    ///
    /// `kind` and `group` are fixed at creation (D-004), so transactions can copy them (see ``MoneyTransaction``).
    /// Seeded names are user data, not UI strings: they stay Indonesian and are not localized (D-008, D-023).
    @Model
    public final class Subcategory {
        /// Stable across edits, backups and restores (D-019). Rollups and transactions refer to it.
        @Attribute(.unique) public private(set) var id: UUID
        /// One word, ≤ 10 characters (D-007, ``SubcategoryRules``).
        public var name: String
        public var emoji: String
        /// ``TransactionKind`` raw value. Stored as a string so predicates and the backup stay simple.
        public private(set) var kindRaw: String
        /// ``ExpenseGroup`` raw value for expenses, nil for income (D-003, D-005).
        public private(set) var groupRaw: String?
        /// Position within its section (Pemasukan, Kebutuhan or Keinginan), ascending.
        public var sortOrder: Int
        /// Hidden instead of deleted once it has history (D-006).
        public var isHidden: Bool
        /// Position on Home, ascending from 0; nil when not pinned. At most 9 pins (D-012).
        public var pinOrder: Int?
        /// Standing monthly budget in rupiah, applied every month; nil = no budget (D-041).
        /// Always nil for income. Set it with ``setMonthlyBudget(_:)``.
        public private(set) var monthlyBudget: Int64?
        public private(set) var createdAt: Date

        /// The transactions in this subcategory. Deleting a subcategory nullifies their link;
        /// the app hides used subcategories instead of deleting them (D-006).
        @Relationship(deleteRule: .nullify, inverse: \MoneyTransaction.subcategory)
        public private(set) var transactions: [MoneyTransaction] = []

        /// - Precondition: expenses have a group and income has none (``SubcategoryRules/isValidPlacement(kind:group:)``).
        public init(
            id: UUID = UUID(),
            name: String,
            emoji: String,
            kind: TransactionKind,
            group: ExpenseGroup?,
            sortOrder: Int,
            isHidden: Bool = false,
            pinOrder: Int? = nil,
            createdAt: Date = .now
        ) {
            precondition(SubcategoryRules.isValidPlacement(kind: kind, group: group), "expenses need a group, income has none")
            self.id = id
            self.name = name
            self.emoji = emoji
            self.kindRaw = kind.rawValue
            self.groupRaw = group?.rawValue
            self.sortOrder = sortOrder
            self.isHidden = isHidden
            self.pinOrder = pinOrder
            self.createdAt = createdAt
        }

        public var kind: TransactionKind {
            TransactionKind(rawValue: kindRaw) ?? .expense
        }

        public var group: ExpenseGroup? {
            groupRaw.flatMap(ExpenseGroup.init(rawValue:))
        }

        public var isPinned: Bool { pinOrder != nil }

        /// Sets or clears this subcategory's monthly budget (D-041). Zero or negative clears it.
        /// It need not fit inside the group budget, so it isn't checked against it.
        /// - Throws: ``BudgetError/incomeHasNoBudget`` when setting a budget on an income subcategory.
        public func setMonthlyBudget(_ amount: Int64?) throws(BudgetError) {
            let value = amount.flatMap { $0 > 0 ? $0 : nil }
            if value != nil, kind == .income { throw .incomeHasNoBudget }
            monthlyBudget = value
        }
    }
}
