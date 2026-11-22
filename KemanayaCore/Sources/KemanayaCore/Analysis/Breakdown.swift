import Foundation

/// The Rincian section of Analisis (D-014, D-051): a month's expense subcategories ranked by total,
/// with each one's share of the filtered spending. Income is never part of it.
public struct Breakdown: Equatable, Sendable {
    /// One ranked subcategory: a donut sector and a list row.
    public struct Slice: Equatable, Sendable, Identifiable {
        public let subcategoryID: UUID
        public let group: ExpenseGroup
        /// Rupiah spent in the month (D-016), always > 0.
        public let total: Int64
        /// Number of transactions.
        public let count: Int
        /// ``total`` ÷ the breakdown's total, `0...1`. Exact, for drawing.
        public let share: Double
        /// Whole percent for display. The slices' percents add up to exactly 100 (largest remainder),
        /// so a small slice can read 0; see ``isUnderOnePercent``.
        public let percent: Int

        public var id: UUID { subcategoryID }

        /// True when the slice rounds to 0 % but isn't empty: the UI says "<1%" instead of a false 0 %.
        public var isUnderOnePercent: Bool { percent == 0 && total > 0 }
    }

    public let filter: ExpenseFilter
    /// Sum of the slices.
    public let total: Int64
    /// Largest total first; ties keep ``MonthSummary``'s stable order (more transactions first, then id).
    public let slices: [Slice]

    /// - Parameter transactions: the month's transactions (any kinds; income and other groups are dropped).
    public init(_ transactions: some Sequence<TransactionSnapshot>, filter: ExpenseFilter = .all) {
        self.init(summary: MonthSummary(transactions), filter: filter)
    }

    /// From an existing month summary, so a screen that already has one doesn't sum twice.
    public init(summary: MonthSummary, filter: ExpenseFilter = .all) {
        let kept = summary.expenseSubcategories.filter { filter.includes(group: $0.group) && $0.total > 0 }
        // Clamps like MonthSummary's sums: a year's ranking (YearRecap) adds twelve months.
        let total = kept.lazy.map(\.total).saturatingSum()
        let percents = Self.wholePercents(of: kept.map(\.total), total: total)
        self.filter = filter
        self.total = total
        self.slices = zip(kept, percents).compactMap { item, percent in
            guard let group = item.group else { return nil }
            return Slice(
                subcategoryID: item.subcategoryID,
                group: group,
                total: item.total,
                count: item.count,
                share: total > 0 ? Double(item.total) / Double(total) : 0,
                percent: percent
            )
        }
    }

    /// Nothing spent in the month for this filter: the screen shows its empty note.
    public var isEmpty: Bool { slices.isEmpty }

    /// The biggest slice, for the friendly line "paling banyak di …" (D-022 voice).
    public var largest: Slice? { slices.first }

    /// How many ranked rows the Analisis page shows under the donut (D-070); the rest are behind
    /// **Lihat semua**.
    public static let topLimit = 5

    /// The first `limit` slices, in the donut's order (D-070). All of them when there are fewer; none
    /// for a limit of 0 or less.
    public func topSlices(limit: Int = Breakdown.topLimit) -> ArraySlice<Slice> {
        slices.prefix(max(limit, 0))
    }

    /// True when ``topSlices(limit:)`` leaves slices out, so the page shows **Lihat semua** (D-070).
    /// False at exactly `limit` slices: nothing is hidden.
    public func hasMore(than limit: Int = Breakdown.topLimit) -> Bool {
        slices.count > max(limit, 0)
    }

    /// Whole percents of `total` that add up to 100 (largest remainder; ties go to the earlier, larger
    /// slice). All zero when `total` is zero. Integer math with a full-width product, so no amount overflows.
    static func wholePercents(of amounts: [Int64], total: Int64) -> [Int] {
        guard total > 0 else { return amounts.map { _ in 0 } }
        var floors: [Int] = []
        var remainders: [Int64] = []
        for amount in amounts {
            let clamped = min(max(amount, 0), total)
            let (quotient, remainder) = total.dividingFullWidth(clamped.multipliedFullWidth(by: 100))
            floors.append(Int(quotient))
            remainders.append(remainder)
        }
        let missing = 100 - floors.reduce(0, +)
        let order = remainders.indices.sorted { remainders[$0] != remainders[$1] ? remainders[$0] > remainders[$1] : $0 < $1 }
        for index in order.prefix(max(missing, 0)) {
            floors[index] += 1
        }
        return floors
    }
}
