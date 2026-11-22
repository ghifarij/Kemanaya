/// This month's total against last month's: a Home card's "Bulan lalu" (D-068) and the subcategory detail's comparison (D-051).
public struct MonthComparison: Equatable, Sendable {
    /// Which way the total moved. Deliberately neutral: no "good" or "bad" (D-022).
    public enum Direction: Equatable, Sendable {
        case up, down, same
    }

    /// This month's total. Negative input is treated as zero.
    public let current: Int64
    /// Last month's total. Negative input is treated as zero.
    public let previous: Int64

    public init(current: Int64, previous: Int64) {
        self.current = max(current, 0)
        self.previous = max(previous, 0)
    }

    public var direction: Direction {
        current > previous ? .up : current < previous ? .down : .same
    }

    /// This month as a fraction of the larger of the two months, `0...1`.
    public var currentFraction: Double { fraction(of: current) }

    /// Last month as a fraction of the larger of the two months, `0...1`.
    public var previousFraction: Double { fraction(of: previous) }

    private func fraction(of amount: Int64) -> Double {
        let largest = max(current, previous)
        return largest == 0 ? 0 : Double(amount) / Double(largest)
    }
}
