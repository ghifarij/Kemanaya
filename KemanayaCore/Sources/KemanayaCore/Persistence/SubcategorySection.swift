/// One titled block of the add sheet's subcategory grid (D-043): Kebutuhan, Keinginan, or the flat income list.
/// Built by ``Ledger/gridSections(for:including:)`` or ``sections(from:kinds:)``. Holds models, so it stays on the context's actor.
public struct SubcategorySection: Identifiable {
    public let kind: TransactionKind
    /// The expense group, or nil for the income section (D-005).
    public let group: ExpenseGroup?
    /// Visible subcategories in grid order.
    public let subcategories: [Subcategory]

    /// `kebutuhan`, `keinginan` or `income`: stable across fetches, for `ForEach`.
    public var id: String { group?.rawValue ?? kind.rawValue }

    public init(kind: TransactionKind, group: ExpenseGroup?, subcategories: [Subcategory]) {
        self.kind = kind
        self.group = group
        self.subcategories = subcategories
    }
}

extension SubcategorySection {
    /// Splits `subcategories`, already in grid order, into the grid's sections for each of `kinds` in turn:
    /// expenses as Kebutuhan then Keinginan, income as one flat section. Order within a section is kept,
    /// and empty sections are left out. Used by the add sheet's grid and by pin management (D-043, D-048).
    public static func sections(from subcategories: [Subcategory], kinds: [TransactionKind]) -> [SubcategorySection] {
        kinds.flatMap { kind -> [SubcategorySection] in
            let ofKind = subcategories.filter { $0.kind == kind }
            return switch kind {
            case .income:
                [SubcategorySection(kind: .income, group: nil, subcategories: ofKind)]
            case .expense:
                ExpenseGroup.allCases.map { group in
                    SubcategorySection(kind: .expense, group: group, subcategories: ofKind.filter { $0.group == group })
                }
            }
        }
        .filter { !$0.subcategories.isEmpty }
    }
}
