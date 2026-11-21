import Foundation
import SwiftData

/// Pengaturan's subcategory and budget writes (D-006, D-007, D-041, D-062). Same discipline as
/// `Ledger+Writes.swift`: every write validates first, then changes the context and saves once.
///
/// - A refused write (``SubcategoryError``, ``BudgetError``) changes nothing.
/// - A failed save puts every changed value back, then rolls the context back and rethrows, because
///   SwiftData's `rollback()` drops pending inserts and deletes but doesn't revert attributes of saved models.
///
/// Rules:
/// - **Names** are trimmed, one word of at most ten characters (D-007), and unique across every subcategory
///   of both kinds, hidden ones included, ignoring case and diacritics (``SubcategoryRules/nameProblem(_:takenNames:)``).
/// - **Kind and group** are chosen when adding and never change (D-004, D-005).
/// - **Budgets** (D-041): nil or zero clears one; more than ``AmountEntry/maximum`` is refused; income has none.
/// - **Removing** deletes a subcategory without history, hides one with history (D-006, which unpins it,
///   D-049), and refuses the last visible one of its kind or group, so the add sheet always has a tile.
extension Ledger {
    // MARK: - Reads

    /// Every subcategory of `kind`, hidden ones included, in grid order: by `sortOrder`, ties by name.
    /// Expenses of both groups come mixed; split them with ``SubcategorySection/sections(from:kinds:)``.
    public func subcategories(of kind: TransactionKind) throws -> [Subcategory] {
        let kindRaw = kind.rawValue
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.kindRaw == kindRaw },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    /// Why `name` can't be saved, or nil when it can (D-007, D-062).
    /// - Parameter excluded: the subcategory being renamed, whose own name doesn't count as taken.
    public func nameProblem(for name: String, excluding excluded: Subcategory? = nil) throws -> SubcategoryNameProblem? {
        let excludedID = excluded?.id
        let taken = try context.fetch(FetchDescriptor<Subcategory>())
            .filter { $0.id != excludedID }
            .map(\.name)
        return SubcategoryRules.nameProblem(name, takenNames: taken)
    }

    /// What ``removeSubcategory(_:)`` would do to `subcategory`, for the confirmation (D-062).
    public func removal(for subcategory: Subcategory) throws -> SubcategoryRemoval {
        if !subcategory.isHidden, try isLastVisible(subcategory) { return .notAllowed }
        return try hasHistory(subcategory) ? .hide : .delete
    }

    // MARK: - Subcategory writes

    /// Adds a visible, unpinned subcategory at the end of its section (Pemasukan, Kebutuhan or Keinginan) and saves.
    ///
    /// - Parameters:
    ///   - name: trimmed before it is checked and stored.
    ///   - group: the expense group (D-004); nil for income (D-005).
    ///   - monthlyBudget: expenses only; nil or zero means none.
    /// - Throws: ``SubcategoryError`` for a bad name, emoji or placement; ``BudgetError`` for a budget on
    ///   income or over the keypad maximum; otherwise the save error.
    @discardableResult
    public func addSubcategory(
        name: String,
        emoji: String,
        kind: TransactionKind,
        group: ExpenseGroup?,
        monthlyBudget: Int64? = nil,
        now: Date = .now
    ) throws -> Subcategory {
        guard SubcategoryRules.isValidPlacement(kind: kind, group: group) else { throw SubcategoryError.invalidPlacement }
        let (name, emoji) = try validated(name: name, emoji: emoji, excluding: nil)
        let budget = try Self.validatedBudget(monthlyBudget, kind: kind)
        let section = try subcategories(of: kind).filter { $0.group == group }
        let subcategory = Subcategory(
            name: name,
            emoji: emoji,
            kind: kind,
            group: group,
            sortOrder: (section.map(\.sortOrder).max() ?? -1) + 1,
            createdAt: now
        )
        try subcategory.setMonthlyBudget(budget)
        context.insert(subcategory)
        try saveOrRollBack()
        return subcategory
    }

    /// Replaces the name, emoji and monthly budget of `subcategory` and saves. Its kind and group stay
    /// (D-004). Transactions follow it, so History and Analisis show the new name; rollups keep their
    /// snapshot names (D-059, D-062).
    ///
    /// - Parameter monthlyBudget: nil or zero clears it; must be nil (or zero) for income.
    /// - Throws: ``SubcategoryError`` for a bad name or emoji, ``BudgetError`` for a bad budget; otherwise the save error.
    public func updateSubcategory(_ subcategory: Subcategory, name: String, emoji: String, monthlyBudget: Int64?) throws {
        let (name, emoji) = try validated(name: name, emoji: emoji, excluding: subcategory)
        let budget = try Self.validatedBudget(monthlyBudget, kind: subcategory.kind)
        let old = (name: subcategory.name, emoji: subcategory.emoji, budget: subcategory.monthlyBudget)
        guard name != old.name || emoji != old.emoji || budget != old.budget else { return }
        subcategory.name = name
        subcategory.emoji = emoji
        try subcategory.setMonthlyBudget(budget)
        try saveOrRollBack {
            subcategory.name = old.name
            subcategory.emoji = old.emoji
            try? subcategory.setMonthlyBudget(old.budget)
        }
    }

    /// Moves visible subcategories within one section, with the same meaning as SwiftUI's `onMove`: the
    /// offsets index the section's *visible* subcategories in grid order, and `destination` is an offset in
    /// that list before the move. The new order is the add sheet's grid order (D-062).
    ///
    /// The whole section is renumbered `0..<n`: visible ones in the new order, then hidden ones in their old
    /// order, so a subcategory shown again with Tampilkan comes back at the end.
    /// - Parameter group: the expense group; nil for income.
    public func moveSubcategories(kind: TransactionKind, group: ExpenseGroup?, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        guard SubcategoryRules.isValidPlacement(kind: kind, group: group) else { throw SubcategoryError.invalidPlacement }
        let section = try subcategories(of: kind).filter { $0.group == group }
        let visible = section.filter { !$0.isHidden }
        let ordered = PinOrder.moving(visible, fromOffsets: source, toOffset: destination) + section.filter(\.isHidden)
        let old = ordered.map { (subcategory: $0, sortOrder: $0.sortOrder) }
        var changed = false
        for (index, subcategory) in ordered.enumerated() where subcategory.sortOrder != index {
            subcategory.sortOrder = index
            changed = true
        }
        guard changed else { return }
        try saveOrRollBack {
            for entry in old { entry.subcategory.sortOrder = entry.sortOrder }
        }
    }

    /// Removes `subcategory` (D-006, D-062): deletes it when no transaction or rollup refers to it, and hides
    /// it otherwise (which unpins it, D-049). The cards after a removed pin move up.
    /// Removing an already hidden subcategory with history does nothing.
    ///
    /// - Returns: ``SubcategoryRemoval/delete`` or ``SubcategoryRemoval/hide``, whichever happened.
    /// - Throws: ``SubcategoryError/lastVisibleInSection`` for the last visible one of its kind or group;
    ///   otherwise the save error.
    @discardableResult
    public func removeSubcategory(_ subcategory: Subcategory) throws -> SubcategoryRemoval {
        switch try removal(for: subcategory) {
        case .notAllowed:
            throw SubcategoryError.lastVisibleInSection
        case .hide:
            try hide(subcategory)
            return .hide
        case .delete:
            let remaining = try pinnedSubcategories().filter { $0.id != subcategory.id }
            let old = remaining.map { (subcategory: $0, pinOrder: $0.pinOrder) }
            for (index, pinned) in remaining.enumerated() where pinned.pinOrder != index {
                pinned.pinOrder = index
            }
            context.delete(subcategory)
            try saveOrRollBack {
                for entry in old { entry.subcategory.pinOrder = entry.pinOrder }
            }
            return .delete
        }
    }

    // MARK: - Budget writes

    /// Sets the standing monthly budget of `group` (D-010, D-041) and saves. Nil or zero clears it.
    /// - Throws: ``BudgetError/overMaximum`` above the keypad maximum; otherwise the save error.
    public func setGroupBudget(_ amount: Int64?, for group: ExpenseGroup) throws {
        let budget = try Self.validatedBudget(amount, kind: .expense)
        let settings = try AppSettings.fetchOrCreate(in: context)
        let old = settings.budget(for: group)
        // A just-inserted settings row is saved even when the budget stays the same.
        guard budget != old || context.hasChanges else { return }
        settings.setBudget(budget, for: group)
        try saveOrRollBack { settings.setBudget(old, for: group) }
    }

    /// Sets the standing monthly budget of an expense subcategory (D-041) and saves. Nil or zero clears it.
    /// - Throws: ``BudgetError/incomeHasNoBudget`` for income (clearing is fine), ``BudgetError/overMaximum``
    ///   above the keypad maximum; otherwise the save error.
    public func setMonthlyBudget(_ amount: Int64?, for subcategory: Subcategory) throws {
        let budget = try Self.validatedBudget(amount, kind: subcategory.kind)
        let old = subcategory.monthlyBudget
        guard budget != old else { return }
        try subcategory.setMonthlyBudget(budget)
        try saveOrRollBack { try? subcategory.setMonthlyBudget(old) }
    }

    // MARK: - Helpers

    /// The trimmed name and emoji, or the reason they can't be saved.
    private func validated(name: String, emoji: String, excluding excluded: Subcategory?) throws -> (name: String, emoji: String) {
        if let problem = try nameProblem(for: name, excluding: excluded) { throw SubcategoryError.invalidName(problem) }
        let emoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SubcategoryRules.isValidEmoji(emoji) else { throw SubcategoryError.invalidEmoji }
        return (SubcategoryRules.normalizedName(name), emoji)
    }

    /// The budget to store: nil for none (nil, zero or negative).
    /// - Throws: ``BudgetError/overMaximum`` above the keypad maximum, ``BudgetError/incomeHasNoBudget`` for
    ///   a budget on income.
    static func validatedBudget(_ amount: Int64?, kind: TransactionKind) throws(BudgetError) -> Int64? {
        guard let amount, amount > 0 else { return nil }
        guard amount <= AmountEntry.maximum else { throw .overMaximum }
        guard kind == .expense else { throw .incomeHasNoBudget }
        return amount
    }

    /// True when a transaction or rollup refers to `subcategory`'s id (D-006), counting by the stored id.
    private func hasHistory(_ subcategory: Subcategory) throws -> Bool {
        let id = subcategory.id
        var transactions = FetchDescriptor<MoneyTransaction>(predicate: #Predicate { $0.subcategoryID == id })
        transactions.fetchLimit = 1
        if try context.fetchCount(transactions) > 0 { return true }
        var rollups = FetchDescriptor<MonthlyRollup>(predicate: #Predicate { $0.subcategoryID == id })
        rollups.fetchLimit = 1
        return try context.fetchCount(rollups) > 0
    }

    /// True when no other visible subcategory shares `subcategory`'s kind and group.
    private func isLastVisible(_ subcategory: Subcategory) throws -> Bool {
        try !subcategories(of: subcategory.kind).contains {
            $0.id != subcategory.id && !$0.isHidden && $0.group == subcategory.group
        }
    }
}
