import Foundation

/// Riwayat's filter (D-074): any of the three groups, Kebutuhan, Keinginan and Pemasukan (the Home
/// sections, ``PinSection``), and any subcategories. An empty set means "all" for that part, so the
/// empty filter shows everything. A row passes when its group is selected (or none is) **and** its
/// subcategory is selected (or none is). The filter combines with search: both must match.
///
/// Edited as a draft in the filter sheet and applied with Terapkan; the chips above the list remove one
/// item at a time. It lasts for the session and is never stored.
///
/// The subcategory helpers take `sectionOf`, which looks up a subcategory's group by id
/// (``Subcategory/pinSection``); nil means the subcategory is unknown.
public struct HistoryFilter: Hashable, Sendable {
    /// The selected groups; empty = every group.
    public var groups: Set<PinSection>
    /// The selected subcategories (``Subcategory/id``); empty = every subcategory.
    public var subcategoryIDs: Set<UUID>

    public init(groups: Set<PinSection> = [], subcategoryIDs: Set<UUID> = []) {
        self.groups = groups
        self.subcategoryIDs = subcategoryIDs
    }

    /// Nothing selected: every transaction shows.
    public var isEmpty: Bool { groups.isEmpty && subcategoryIDs.isEmpty }

    /// How many items are selected, one per chip above the list ("2 filter aktif").
    public var count: Int { groups.count + subcategoryIDs.count }

    // MARK: - Matching

    /// Whether a transaction of `kind`, `group` (nil for income) and subcategory passes.
    public func matches(kind: TransactionKind, group: ExpenseGroup?, subcategoryID: UUID) -> Bool {
        (groups.isEmpty || groups.contains(PinSection(kind: kind, group: group)))
            && (subcategoryIDs.isEmpty || subcategoryIDs.contains(subcategoryID))
    }

    /// Whether `entry` passes.
    public func matches(_ entry: some HistoryEntry) -> Bool {
        matches(kind: entry.kind, group: entry.group, subcategoryID: entry.subcategoryID)
    }

    // MARK: - What the filter can show

    /// The groups whose subcategories the sheet offers, in display order: the selected groups, or all
    /// three when none is selected.
    public var offeredSections: [PinSection] {
        groups.isEmpty ? PinSection.allCases : PinSection.allCases.filter(groups.contains)
    }

    /// The kinds a row passing this filter can have, so a month header shows a figure only for them
    /// (D-074): expenses unless only income is selected, income unless only expenses are. A selected
    /// subcategory narrows it to its own kind; an unknown one narrows nothing.
    public func allowedKinds(sectionOf: (UUID) -> PinSection?) -> Set<TransactionKind> {
        var kinds = Set(TransactionKind.allCases)
        if !groups.isEmpty {
            kinds.formIntersection(groups.map(\.kind))
        }
        if !subcategoryIDs.isEmpty {
            let sections = subcategoryIDs.map(sectionOf)
            if !sections.contains(nil) {
                kinds.formIntersection(sections.compactMap { $0?.kind })
            }
        }
        return kinds
    }

    // MARK: - Editing

    /// Selects `section`, or deselects it and drops its selected subcategories. Selecting one also drops
    /// subcategories of the groups left out (``pruned(sectionOf:)``), so no selection contradicts another.
    public func toggling(_ section: PinSection, sectionOf: (UUID) -> PinSection?) -> HistoryFilter {
        if groups.contains(section) { return removing(section, sectionOf: sectionOf) }
        var filter = self
        filter.groups.insert(section)
        return filter.pruned(sectionOf: sectionOf)
    }

    /// Selects or deselects one subcategory.
    public func toggling(subcategory id: UUID) -> HistoryFilter {
        subcategoryIDs.contains(id) ? removing(subcategory: id) : HistoryFilter(groups: groups, subcategoryIDs: subcategoryIDs.union([id]))
    }

    /// Without `section`, and without its selected subcategories: deselecting a group drops them.
    public func removing(_ section: PinSection, sectionOf: (UUID) -> PinSection?) -> HistoryFilter {
        HistoryFilter(
            groups: groups.subtracting([section]),
            subcategoryIDs: subcategoryIDs.filter { sectionOf($0) != section }
        )
    }

    /// Without the subcategory `id`.
    public func removing(subcategory id: UUID) -> HistoryFilter {
        HistoryFilter(groups: groups, subcategoryIDs: subcategoryIDs.subtracting([id]))
    }

    /// Without the selected subcategories outside the selected groups, which could never match (the
    /// sheet hides them too). Unchanged while no group is selected.
    public func pruned(sectionOf: (UUID) -> PinSection?) -> HistoryFilter {
        guard !groups.isEmpty else { return self }
        return HistoryFilter(
            groups: groups,
            subcategoryIDs: subcategoryIDs.filter { sectionOf($0).map(groups.contains) ?? false }
        )
    }
}

extension PinSection {
    /// Pemasukan is income; Kebutuhan and Keinginan are expenses.
    public var kind: TransactionKind {
        self == .pemasukan ? .income : .expense
    }
}

extension HistoryTotals {
    /// The figures a month header shows, in order (D-073, D-074): Pengeluaran whenever `kinds` allows
    /// expenses, even Rp0, and Pemasukan when `kinds` allows income and the month has some. Unfiltered,
    /// `kinds` is every kind. The totals come from the rows shown, so under a filter they cover only them.
    public func figures(allowing kinds: Set<TransactionKind> = Set(TransactionKind.allCases)) -> [TransactionKind] {
        var figures: [TransactionKind] = []
        if kinds.contains(.expense) { figures.append(.expense) }
        if kinds.contains(.income), hasIncome { figures.append(.income) }
        return figures
    }

    /// The total of one kind.
    public func amount(of kind: TransactionKind) -> Int64 {
        switch kind {
        case .expense: expenses
        case .income: income
        }
    }
}
