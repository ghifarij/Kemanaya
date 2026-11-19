import Foundation

/// Everything Home shows for one month, as plain values (D-009, D-012, D-014, D-041, D-048):
/// the month's totals, each pinned card's total against last month, and budget progress only where a
/// budget is set. Built from snapshots, so it is tested without SwiftData and computed on any actor.
public struct HomeOverview: Equatable, Sendable {
    /// What Home knows about a pinned subcategory before aggregating.
    public struct Pin: Equatable, Sendable {
        public let id: UUID
        /// ``Subcategory/monthlyBudget``; always nil for income (D-041).
        public let monthlyBudget: Int64?

        public init(id: UUID, monthlyBudget: Int64?) {
            self.id = id
            self.monthlyBudget = monthlyBudget
        }
    }

    /// One pinned card's numbers.
    public struct Card: Equatable, Sendable, Identifiable {
        /// The subcategory's id.
        public let id: UUID
        /// This month's total against last month's, for the card's tiny bars.
        public let comparison: MonthComparison
        /// Progress against the subcategory budget; nil when it has none, so the card shows nothing.
        public let budget: BudgetProgress?
    }

    /// A group budget that is set, with its progress.
    public struct GroupBudget: Equatable, Sendable, Identifiable {
        public let group: ExpenseGroup
        public let progress: BudgetProgress

        public var id: ExpenseGroup { group }
    }

    /// The month on screen.
    public let month: MonthSummary
    /// One per pin, in the order given (Home order).
    public let cards: [Card]
    /// Kebutuhan then Keinginan, only those with a budget. Empty on a fresh install (D-048).
    public let groupBudgets: [GroupBudget]

    /// - Parameters:
    ///   - current: the month's transactions (``Ledger`` fetches them by date range).
    ///   - previous: the month before's, for the cards' comparison.
    ///   - pins: pinned subcategories in Home order.
    ///   - groupBudgets: standing group budgets (``AppSettings/budget(for:)``); a missing, zero or
    ///     negative value means no budget.
    public init(
        current: some Sequence<TransactionSnapshot>,
        previous: some Sequence<TransactionSnapshot>,
        pins: [Pin],
        groupBudgets: [ExpenseGroup: Int64]
    ) {
        let month = MonthSummary(current)
        let lastMonth = MonthSummary(previous)
        self.month = month
        self.cards = pins.map { pin in
            Card(
                id: pin.id,
                comparison: MonthComparison(current: month.total(for: pin.id), previous: lastMonth.total(for: pin.id)),
                budget: month.budgetProgress(forSubcategory: pin.id, budget: pin.monthlyBudget)
            )
        }
        self.groupBudgets = ExpenseGroup.allCases.compactMap { group in
            month.budgetProgress(for: group, budget: groupBudgets[group]).map { GroupBudget(group: group, progress: $0) }
        }
    }

    /// True when the month has no transactions yet: Home shows its calm empty state instead of totals.
    public var isEmpty: Bool { month.subcategories.isEmpty }

    /// The card for subcategory `id`, if it is pinned.
    public func card(for id: UUID) -> Card? {
        cards.first { $0.id == id }
    }
}
