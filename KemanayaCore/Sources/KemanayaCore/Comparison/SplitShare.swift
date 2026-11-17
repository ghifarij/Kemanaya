/// How two amounts split a whole, e.g. Kebutuhan vs Keinginan on Home (D-014).
public struct SplitShare: Equatable, Sendable {
    /// The first amount. Negative input is treated as zero.
    public let first: Int64
    /// The second amount. Negative input is treated as zero.
    public let second: Int64

    public init(first: Int64, second: Int64) {
        self.first = max(first, 0)
        self.second = max(second, 0)
    }

    /// True when both amounts are zero.
    public var isEmpty: Bool { first == 0 && second == 0 }

    /// The first amount's share of the total, `0...1`. Zero when empty.
    /// Computed in `Double`, so two huge amounts cannot overflow.
    public var firstFraction: Double {
        isEmpty ? 0 : Double(first) / (Double(first) + Double(second))
    }

    /// Whole percentages that always add up to 100 (or are both 0 when empty).
    /// A non-zero side never shows as 0 %, and a side never shows 100 % while the other is non-zero.
    public var percentages: (first: Int, second: Int) {
        if isEmpty { return (0, 0) }
        if second == 0 { return (100, 0) }
        if first == 0 { return (0, 100) }
        let rounded = Int((firstFraction * 100).rounded())
        let firstPercent = min(max(rounded, 1), 99)
        return (firstPercent, 100 - firstPercent)
    }

    /// Widths for drawing the two segments in `totalWidth` with `gap` between them.
    /// A non-zero side gets at least `minimumWidth` so tiny shares stay visible.
    /// When one side is zero, the other takes the full width and no gap is drawn.
    public func segmentWidths(totalWidth: Double, gap: Double, minimumWidth: Double) -> (first: Double, second: Double) {
        let total = max(totalWidth, 0)
        if isEmpty { return (0, 0) }
        if second == 0 { return (total, 0) }
        if first == 0 { return (0, total) }
        let available = max(total - gap, 0)
        let floor = min(minimumWidth, available / 2)
        let firstWidth = min(max(available * firstFraction, floor), available - floor)
        return (firstWidth, available - firstWidth)
    }
}
