import Foundation

/// What a subcategory is called on screen.
public struct SubcategoryLabel: Equatable, Sendable {
    public let name: String
    public let emoji: String

    public init(name: String, emoji: String) {
        self.name = name
        self.emoji = emoji
    }
}

/// The yearly recap (D-014, D-017, D-059): a calendar year's pengeluaran and pemasukan, the Kebutuhan /
/// Keinginan split, the twelve months, and the expense subcategories ranked by total. It reads rollups
/// for purged months and raw transactions for the rest (``MonthTotals``), so a completed year stays whole
/// forever. The current year is year to date. Neutral numbers only (D-022); no transaction rows, because
/// purged months have none.
public struct YearRecap: Equatable, Sendable {
    /// The Gregorian year, e.g. 2026.
    public let year: Int
    /// True for the current year: it shows "sampai hari ini" (year to date).
    public let isYearToDate: Bool
    /// The whole year's totals: ``MonthSummary/expenses``, ``MonthSummary/income``, the groups.
    public let summary: MonthSummary
    /// The year's expense subcategories, largest total first, with their shares (all groups).
    public let ranking: Breakdown
    /// January to December, with zeros for months without money (and the rest of a year to date).
    public let months: [MonthlyFlow]
    /// The name and emoji of every ranked subcategory: the current subcategory's when it still exists,
    /// otherwise the newest rollup snapshot's. Missing when neither is known (an orphan, D-006).
    public let labels: [UUID: SubcategoryLabel]

    /// - Parameters:
    ///   - transactions: raw transactions; only those dated in `year` (in `timeZone`) count.
    ///   - rollups: rollups; only those of `year`'s months count.
    ///   - current: the current month, which decides whether `year` is year to date.
    ///   - subcategories: the current name and emoji of each subcategory that still exists, by id.
    public init(
        year: Int,
        transactions: some Sequence<TransactionSnapshot>,
        rollups: some Sequence<RollupSnapshot>,
        current: MonthKey,
        subcategories: [UUID: SubcategoryLabel],
        timeZone: TimeZone
    ) {
        let yearTransactions = transactions.filter { MonthKey(containing: $0.date, timeZone: timeZone).year == year }
        let yearRollups = rollups.filter { $0.month.year == year }
        let totals = MonthTotals(transactions: yearTransactions, rollups: yearRollups, timeZone: timeZone)
        self.year = year
        self.isYearToDate = year == current.year
        self.months = Self.months(of: year).map { month in
            let summary = totals.summary(for: month)
            return MonthlyFlow(month: month, expenses: summary.expenses, income: summary.income)
        }
        // The same sum as the months' (raw plus rollups, D-055) over the whole year at once, so each
        // subcategory's total adds up across months.
        let summary = MonthSummary(yearTransactions, rollups: yearRollups)
        let ranking = Breakdown(summary: summary)
        self.summary = summary
        self.ranking = ranking
        var snapshots: [UUID: (month: MonthKey, label: SubcategoryLabel)] = [:]
        for rollup in yearRollups where !rollup.name.isEmpty {
            if let known = snapshots[rollup.subcategoryID], known.month >= rollup.month { continue }
            snapshots[rollup.subcategoryID] = (rollup.month, SubcategoryLabel(name: rollup.name, emoji: rollup.emoji))
        }
        self.labels = ranking.slices.reduce(into: [:]) { result, slice in
            result[slice.subcategoryID] = subcategories[slice.subcategoryID] ?? snapshots[slice.subcategoryID]?.label
        }
    }

    /// Kebutuhan + Keinginan for the year.
    public var expenses: Int64 { summary.expenses }

    /// Pemasukan for the year.
    public var income: Int64 { summary.income }

    /// No money moved in the year: the screen shows its empty note.
    public var isEmpty: Bool { summary.subcategories.isEmpty }

    /// January to December of `year`.
    public static func months(of year: Int) -> [MonthKey] {
        (1...12).map { MonthKey(year: year, month: $0) }
    }

    /// The fetch range for a year's transactions (D-018): 1 January 00:00 up to 1 January of the next year.
    public static func dateRange(of year: Int, timeZone: TimeZone) -> Range<Date> {
        MonthKey(year: year, month: 1).start(in: timeZone)..<MonthKey(year: year + 1, month: 1).start(in: timeZone)
    }
}

/// The years the recap's stepper can show (D-059): from the earliest year with any data, rollup or raw,
/// through the current year.
public struct YearRecapRange: Equatable, Sendable {
    public let earliest: Int
    /// The current year. Later years can't hold entries (D-044).
    public let latest: Int

    /// - Parameter earliestMonth: the oldest month with a transaction or rollup; nil when there is none,
    ///   and then only the current year is shown.
    public init(earliestMonth: MonthKey?, current: MonthKey) {
        self.latest = current.year
        self.earliest = min(earliestMonth?.year ?? current.year, current.year)
    }

    public func contains(_ year: Int) -> Bool {
        earliest <= year && year <= latest
    }

    /// `year` pulled into the range.
    public func clamped(_ year: Int) -> Int {
        min(max(year, earliest), latest)
    }

    /// The year the stepper's ‹ goes to, or nil at ``earliest``.
    public func year(before year: Int) -> Int? {
        let target = clamped(year) - 1
        return contains(target) ? target : nil
    }

    /// The year the stepper's › goes to, or nil at ``latest``.
    public func year(after year: Int) -> Int? {
        let target = clamped(year) + 1
        return contains(target) ? target : nil
    }
}
