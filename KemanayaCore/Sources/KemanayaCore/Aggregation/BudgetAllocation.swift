/// How a group's subcategory budgets sit inside its group budget (D-077): slices, not extra money.
/// Kebutuhan Rp5jt stays Rp5jt; Makan Rp500rb is part of it, so Rp4,5jt is left unassigned ("bebas").
///
/// Nothing is forced or auto-filled (D-041): the slices may add up to less than the group budget, to more,
/// or exist without one. ``summary`` says which, for the line under the group's row on the Anggaran sheet.
/// Neutral numbers only (D-022).
public struct BudgetAllocation: Equatable, Sendable {
    /// What the line under a group's budget row says.
    public enum Summary: Equatable, Sendable {
        /// No subcategory budgets: no line.
        case none
        /// Subcategory budgets but no group budget: "Rp500rb untuk subkategori".
        case slicesOnly(allocated: Int64)
        /// The slices fit in the group budget: "Rp500rb untuk subkategori · Rp4,5jt bebas". `free` may be 0.
        case within(allocated: Int64, free: Int64)
        /// The slices add up to more than the group budget: "Subkategori Rp5,5jt, lebih dari anggaran …".
        case over(allocated: Int64, overBy: Int64)
    }

    /// The group budget; nil when none is set (a zero or negative value counts as none).
    public let groupBudget: Int64?
    /// The sum of the group's subcategory budgets above zero, clamped to `Int64`'s range.
    public let allocated: Int64

    /// - Parameters:
    ///   - groupBudget: ``AppSettings/budget(for:)``; nil, zero or negative means none.
    ///   - subcategoryBudgets: the group's visible expense subcategories' ``Subcategory/monthlyBudget``;
    ///     nil, zero or negative ones are ignored.
    public init(groupBudget: Int64?, subcategoryBudgets: some Sequence<Int64?>) {
        self.groupBudget = groupBudget.flatMap { $0 > 0 ? $0 : nil }
        allocated = subcategoryBudgets.compactMap { $0.flatMap { $0 > 0 ? $0 : nil } }.saturatingSum()
    }

    /// The group budget not given to a subcategory; nil without a group budget or when over-allocated.
    public var free: Int64? {
        guard let groupBudget, allocated <= groupBudget else { return nil }
        return groupBudget - allocated
    }

    /// How far the slices pass the group budget; nil unless they do.
    public var overBy: Int64? {
        guard let groupBudget, allocated > groupBudget else { return nil }
        // allocated ≤ Int64.max and groupBudget > 0, so this can't overflow.
        return allocated - groupBudget
    }

    /// True when the subcategory budgets add up to more than the group budget. Exactly equal is not over.
    public var isOverAllocated: Bool { overBy != nil }

    public var summary: Summary {
        guard allocated > 0 else { return .none }
        if let overBy { return .over(allocated: allocated, overBy: overBy) }
        if let free { return .within(allocated: allocated, free: free) }
        return .slicesOnly(allocated: allocated)
    }
}
