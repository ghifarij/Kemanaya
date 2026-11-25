import Foundation

/// Everything Home shows for one month, as plain values (D-012, D-041, D-048, D-068): the month's
/// totals, one entry per expense group for the hero, each pinned card's total against last month, and
/// budget progress only where a budget is set. Built from snapshots, so it is tested without SwiftData
/// and computed on any actor.
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
        /// This month's total against last month's, for the card's "Bulan lalu" line (D-068).
        public let comparison: MonthComparison
        /// Progress against the subcategory budget; nil when it has none, so the card shows nothing.
        public let budget: BudgetProgress?
    }

    /// One expense group in the hero (D-073): what it spent, its share of the month's spending (the
    /// split bar and VoiceOver), and its budget progress when one is set.
    public struct GroupRow: Equatable, Sendable, Identifiable {
        public let group: ExpenseGroup
        /// Spent on the group this month.
        public let spent: Int64
        /// Progress against the group budget; nil when it has none.
        public let budget: BudgetProgress?
        /// The group's share of the month's spending, in whole percent. Kebutuhan's and Keinginan's add up
        /// to 100, or are both 0 with no spending (``SplitShare/percentages``).
        public let sharePercent: Int

        public var id: ExpenseGroup { group }
    }

    /// The month on screen.
    public let month: MonthSummary
    /// One per pin, in the order given (Home order).
    public let cards: [Card]
    /// Kebutuhan then Keinginan, always both (D-068).
    public let groups: [GroupRow]

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
        self.init(current: current, previous: MonthSummary(previous), pins: pins, groupBudgets: groupBudgets)
    }

    /// - Parameter previous: the month before's totals from ``MonthTotals`` (D-055, D-059), so the cards
    ///   compare with its rollups should it ever be before the raw window.
    public init(
        current: some Sequence<TransactionSnapshot>,
        previous lastMonth: MonthSummary,
        pins: [Pin],
        groupBudgets: [ExpenseGroup: Int64]
    ) {
        let month = MonthSummary(current)
        self.month = month
        self.cards = pins.map { pin in
            Card(
                id: pin.id,
                comparison: MonthComparison(current: month.total(for: pin.id), previous: lastMonth.total(for: pin.id)),
                budget: month.budgetProgress(forSubcategory: pin.id, budget: pin.monthlyBudget)
            )
        }
        let percentages = SplitShare(first: month.kebutuhan, second: month.keinginan).percentages
        self.groups = ExpenseGroup.allCases.map { group in
            GroupRow(
                group: group,
                spent: month.spent(on: group),
                budget: month.budgetProgress(for: group, budget: groupBudgets[group]),
                sharePercent: group == .kebutuhan ? percentages.first : percentages.second
            )
        }
    }

    /// True when the month has no transactions yet: Home shows its calm empty state instead of totals.
    public var isEmpty: Bool { month.subcategories.isEmpty }

    /// The card for subcategory `id`, if it is pinned.
    public func card(for id: UUID) -> Card? {
        cards.first { $0.id == id }
    }
}
