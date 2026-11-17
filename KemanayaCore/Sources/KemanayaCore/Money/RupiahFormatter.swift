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
