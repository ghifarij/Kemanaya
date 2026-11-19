/// Formats integer rupiah for display, e.g. `Rp1.250.000` (D-016).
///
/// Deterministic on purpose: it never reads `Locale.current`, so the app shows
/// the same Indonesian notation (dot thousands separator, no decimals) on every device.
public enum RupiahFormatter {
    /// `45000` → `Rp45.000`, `-45000` → `-Rp45.000`. Safe for `Int64.min` and `Int64.max`.
    public static func string(from amount: Int64) -> String {
        // `magnitude` is a `UInt64`, so `Int64.min` never overflows.
        let digits = String(amount.magnitude)
        var grouped = ""
        grouped.reserveCapacity(digits.count + digits.count / 3)
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index).isMultiple(of: 3) {
                grouped.append(".")
            }
            grouped.append(digit)
        }
        return (amount < 0 ? "-Rp" : "Rp") + grouped
    }
}

extension Int64 {
    /// This amount as rupiah text, e.g. `Rp45.000`. See ``RupiahFormatter``.
    public var rupiahFormatted: String {
        RupiahFormatter.string(from: self)
    }
}

extension RupiahFormatter {
    /// A short amount for chart axes, in Indonesian abbreviations: `0` → `0`, `500` → `Rp500`,
    /// `250000` → `Rp250rb`, `1500000` → `Rp1,5jt`, `2000000000` → `Rp2M` (miliar), `3·10¹²` → `Rp3T` (triliun).
    /// One decimal at most, rounded half up, with a decimal comma and no trailing `,0`; a value that
    /// rounds up to 1.000 of a unit moves to the next unit (`999950` → `Rp1jt`). Deterministic like
    /// ``string(from:)``: it never reads the device locale.
    public static func compact(_ amount: Int64) -> String {
        if amount == 0 { return "0" }
        let sign = amount < 0 ? "-" : ""
        let magnitude = amount.magnitude
        let units: [(divisor: UInt64, suffix: String)] = [
            (1_000, "rb"), (1_000_000, "jt"), (1_000_000_000, "M"), (1_000_000_000_000, "T"),
        ]
        if magnitude < 1_000 { return "\(sign)Rp\(magnitude)" }
        var unitIndex = units.lastIndex { magnitude >= $0.divisor } ?? 0
        var tenths = roundedTenths(magnitude, divisor: units[unitIndex].divisor)
        // e.g. 999.950 → 1.000,0rb: say 1jt instead.
        if tenths >= 10_000, unitIndex + 1 < units.count {
            unitIndex += 1
            tenths = roundedTenths(magnitude, divisor: units[unitIndex].divisor)
        }
        let whole = tenths / 10
        let fraction = tenths % 10
        let number = fraction == 0 ? "\(whole)" : "\(whole),\(fraction)"
        return "\(sign)Rp\(number)\(units[unitIndex].suffix)"
    }

    /// `magnitude / divisor` in tenths, rounded half up, without overflowing `UInt64`.
    private static func roundedTenths(_ magnitude: UInt64, divisor: UInt64) -> UInt64 {
        let whole = magnitude / divisor
        let rest = magnitude % divisor
        // rest·10 < divisor·10 ≤ 10¹³, far below UInt64.max.
        let (tenth, remainder) = (rest * 10).quotientAndRemainder(dividingBy: divisor)
        return whole * 10 + tenth + (remainder * 2 >= divisor ? 1 : 0)
    }
}
