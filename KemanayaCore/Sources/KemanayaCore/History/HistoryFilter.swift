import Foundation

/// Riwayat's filter (D-074, D-075): three independent groups, Kebutuhan, Keinginan and Pemasukan (the Home
/// sections, ``PinSection``), each ticked or not, and per ticked group any of its subcategories.
///
/// Matching (D-075):
/// - No group ticked: every row passes (the empty filter).
/// - Otherwise a row passes only when its group is ticked, and either none of that group's subcategories
///   is picked (all of the group) or the row's subcategory is one of them. A pick in one group never
///   narrows another: Kebutuhan + Keinginan with Makan + Listrik shows Makan, Listrik and all of Keinginan.
///
/// The picks are stored under their group, so a pick can only exist under a ticked group and unticking
/// a group drops its picks by construction. The filter combines with search: both must match.
///
/// Edited as a draft in the filter sheet and applied with Terapkan; the chips above the list remove one
/// item at a time. It lasts for the session and is never stored.
public struct HistoryFilter: Hashable, Sendable {
    /// The ticked groups, each with its picked subcategories (``Subcategory/id``); an empty set means all
    /// of that group. No key at all = the group is not ticked.
    public private(set) var picks: [PinSection: Set<UUID>]

    /// - Parameter picks: the ticked groups and their picked subcategories; `[:]` is the empty filter.
    public init(_ picks: [PinSection: Set<UUID>] = [:]) {
        self.picks = picks
    }

    /// The ticked groups, with all of each group (no subcategory picked).
    public init(groups: Set<PinSection>) {
        self.init(Dictionary(uniqueKeysWithValues: groups.map { ($0, []) }))
    }

    /// The ticked groups.
    public var groups: Set<PinSection> { Set(picks.keys) }

    /// Every picked subcategory, across the ticked groups.
    public var subcategoryIDs: Set<UUID> { picks.values.reduce(into: []) { $0.formUnion($1) } }

    /// The subcategories picked under `section`; empty when it is unticked or shows all of its group.
    public func picks(in section: PinSection) -> Set<UUID> { picks[section] ?? [] }

    /// Nothing ticked: every transaction shows.
    public var isEmpty: Bool { picks.isEmpty }

    /// How many items are selected, one per chip above the list ("2 filter aktif").
    public var count: Int { picks.count + picks.values.reduce(0) { $0 + $1.count } }

    // MARK: - Matching

    /// Whether a transaction of `kind`, `group` (nil for income) and subcategory passes (D-075).
    public func matches(kind: TransactionKind, group: ExpenseGroup?, subcategoryID: UUID) -> Bool {
        guard !picks.isEmpty else { return true }
        guard let picked = picks[PinSection(kind: kind, group: group)] else { return false }
        return picked.isEmpty || picked.contains(subcategoryID)
    }

    /// Whether `entry` passes.
    public func matches(_ entry: some HistoryEntry) -> Bool {
        matches(kind: entry.kind, group: entry.group, subcategoryID: entry.subcategoryID)
    }

    // MARK: - What the filter can show

    /// The groups whose subcategories the sheet offers, in display order: only the ticked ones, so with
    /// no group ticked the sheet lists just Jenis (D-075).
    public var offeredSections: [PinSection] {
        PinSection.allCases.filter { picks[$0] != nil }
    }

    /// The kinds a row passing this filter can have, so a month header shows a figure only for them
    /// (D-074, D-075): the kinds of the ticked groups, or every kind when none is ticked. Picks never
    /// change it, since they only narrow within their own group.
    public var allowedKinds: Set<TransactionKind> {
        picks.isEmpty ? Set(TransactionKind.allCases) : Set(picks.keys.map(\.kind))
    }

    // MARK: - Editing

    /// Ticks `section` (all of it), or unticks it and drops its picks.
    public func toggling(_ section: PinSection) -> HistoryFilter {
        var filter = self
        filter.picks[section] = picks[section] == nil ? [] : nil
        return filter
    }

    /// Picks or unpicks the subcategory `id` of `section`. Picking under an unticked group ticks it, so a
    /// pick never exists without its group (the sheet only offers ticked groups anyway).
    public func toggling(subcategory id: UUID, in section: PinSection) -> HistoryFilter {
        var filter = self
        if filter.picks[section, default: []].remove(id) == nil {
            filter.picks[section, default: []].insert(id)
        }
        return filter
    }

    /// Without `section` and its picks: the group's chip takes its subcategories with it.
    public func removing(_ section: PinSection) -> HistoryFilter {
        var filter = self
        filter.picks[section] = nil
        return filter
    }

    /// Without the subcategory `id`; its group stays ticked, so it shows all of that group again once its
    /// last pick goes.
    public func removing(subcategory id: UUID) -> HistoryFilter {
        var filter = self
        for section in picks.keys {
            filter.picks[section]?.remove(id)
        }
        return filter
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
