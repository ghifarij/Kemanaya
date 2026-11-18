/// One titled block of the add sheet's subcategory grid (D-043): Kebutuhan, Keinginan, or the flat income list.
/// Built by ``Ledger/gridSections(for:including:)``. Holds models, so it stays on the context's actor.
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
