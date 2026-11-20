extension Int64 {
    /// `self + other`, clamped to `Int64.min...Int64.max` instead of trapping on overflow.
    ///
    /// Totals use it so no data, however extreme, can crash a screen or a retention run. In valid data it
    /// never clamps: an amount is at most ``AmountEntry/maximum`` (about 10¹²) and `Int64` holds about
    /// 9.2 × 10¹⁸, so a sum clamps only past roughly nine million maximum-size entries.
    func saturatingAdding(_ other: Int64) -> Int64 {
        let (sum, overflow) = addingReportingOverflow(other)
        guard overflow else { return sum }
        return other > 0 ? .max : .min
    }

    /// `self - other`, clamped like ``saturatingAdding(_:)``.
    func saturatingSubtracting(_ other: Int64) -> Int64 {
        let (difference, overflow) = subtractingReportingOverflow(other)
        guard overflow else { return difference }
        return other > 0 ? .min : .max
    }
}

extension Sequence where Element == Int64 {
    /// The sum, clamped to `Int64`'s range (``Swift/Int64/saturatingAdding(_:)``).
    func saturatingSum() -> Int64 {
        reduce(0) { $0.saturatingAdding($1) }
    }
}
