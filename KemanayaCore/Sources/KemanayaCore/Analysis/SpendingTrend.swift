import Foundation

/// Harian (per day) or Mingguan (per week) buckets for the Tren chart (D-014, D-051).
public enum TrendGranularity: String, CaseIterable, Hashable, Sendable {
    case daily
    case weekly
}

/// One bar of the Tren chart: a day, or a week clipped to the month, with Kebutuhan and Keinginan stacked.
public struct SpendingBucket: Equatable, Sendable, Identifiable {
    /// 0-based position in the month.
    public let index: Int
    /// First day of the month in the bucket, `1...31`.
    public let firstDay: Int
    /// Last day of the month in the bucket; equals ``firstDay`` for a daily bucket.
    public let lastDay: Int
    /// Spent on Kebutuhan, 0 when the filter leaves it out.
    public let kebutuhan: Int64
    /// Spent on Keinginan, 0 when the filter leaves it out.
    public let keinginan: Int64

    public init(index: Int, firstDay: Int, lastDay: Int, kebutuhan: Int64, keinginan: Int64) {
        self.index = index
        self.firstDay = firstDay
        self.lastDay = lastDay
        self.kebutuhan = kebutuhan
        self.keinginan = keinginan
    }

    public var id: Int { index }

    /// Both groups.
    public var total: Int64 { kebutuhan + keinginan }

    public func amount(for group: ExpenseGroup) -> Int64 {
        switch group {
        case .kebutuhan: kebutuhan
        case .keinginan: keinginan
        }
    }
}

/// A month's spending split into days or weeks, Kebutuhan and Keinginan apart, filtered (D-051).
///
/// **Week rule:** weeks run Monday to Sunday, as in Indonesia (ISO 8601), on the Gregorian calendar,
/// and are clipped to the month. So the first bucket runs from the 1st to the first Sunday and the
/// last from the last Monday to the month's end; a month has 4 to 6 weeks. Every day falls in exactly
/// one bucket of its own month, so the weeks add up to the month total and never borrow days from
/// the months around it. The weekday doesn't depend on the device's locale or first weekday setting.
public struct SpendingTrend: Equatable, Sendable {
    public let month: MonthKey
    public let granularity: TrendGranularity
    public let filter: ExpenseFilter
    /// Every day (28–31) or every week (4–6) of the month in order, including empty ones.
    public let buckets: [SpendingBucket]

    /// - Parameters:
    ///   - transactions: any transactions; only expenses dated in `month` (in `timeZone`) that pass
    ///     `filter` count.
    ///   - timeZone: the zone months and days are bucketed in, as for ``MonthKey`` (D-017).
    public init(
        _ transactions: some Sequence<TransactionSnapshot>,
        month: MonthKey,
        timeZone: TimeZone,
        granularity: TrendGranularity,
        filter: ExpenseFilter = .all
    ) {
        let calendar = Calendar.gregorian(in: timeZone)
        let range = month.dateRange(in: timeZone)
        let dayCount = Self.dayCount(of: month)
        var kebutuhan = [Int64](repeating: 0, count: dayCount + 1)
        var keinginan = [Int64](repeating: 0, count: dayCount + 1)
        for transaction in transactions where filter.includes(transaction) && range.contains(transaction.date) {
            let day = calendar.component(.day, from: transaction.date)
            guard (1...dayCount).contains(day) else { continue }
            switch transaction.group {
            case .kebutuhan: kebutuhan[day] += transaction.amount
            case .keinginan: keinginan[day] += transaction.amount
            case nil: continue
            }
        }
        let spans = granularity == .daily ? (1...dayCount).map { $0...$0 } : Self.weeks(of: month)
        self.month = month
        self.granularity = granularity
        self.filter = filter
        self.buckets = spans.enumerated().map { index, days in
            SpendingBucket(
                index: index,
                firstDay: days.lowerBound,
                lastDay: days.upperBound,
                kebutuhan: days.reduce(Int64(0)) { $0 + kebutuhan[$1] },
                keinginan: days.reduce(Int64(0)) { $0 + keinginan[$1] }
            )
        }
    }

    /// All buckets together.
    public var total: Int64 { buckets.reduce(0) { $0 + $1.total } }

    /// Nothing spent in the month for this filter: the chart gives way to an empty note.
    public var isEmpty: Bool { total == 0 }

    /// Days in `month` on the Gregorian calendar, 28–31.
    public static func dayCount(of month: MonthKey) -> Int {
        Calendar.gregorian(in: .gmt).range(of: .day, in: .month, for: month.start(in: .gmt))!.count
    }

    /// The month's Monday-to-Sunday weeks as day ranges, clipped to the month (see the week rule above).
    public static func weeks(of month: MonthKey) -> [ClosedRange<Int>] {
        let calendar = Calendar.gregorian(in: .gmt)
        // 1 = Sunday … 7 = Saturday; shifted so Monday = 0 … Sunday = 6. A calendar date's weekday is
        // the same in every zone, so GMT is used whatever the device zone.
        let weekday = calendar.component(.weekday, from: month.start(in: .gmt))
        let daysBeforeMonday = (weekday + 5) % 7
        let dayCount = dayCount(of: month)
        var weeks: [ClosedRange<Int>] = []
        var first = 1
        var last = 7 - daysBeforeMonday
        while first <= dayCount {
            weeks.append(first...min(last, dayCount))
            first = last + 1
            last = first + 6
        }
        return weeks
    }
}
