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
    /// The abbreviations a compact amount uses, following the app language (D-065). Full amounts stay
    /// `Rp45.000` in both (D-016).
    public enum CompactStyle: Sendable, Equatable {
        /// `Rp250rb`, `Rp1,5jt`, `Rp2M` (miliar), `Rp3T` (triliun), with a decimal comma.
        case indonesian
        /// `Rp250K`, `Rp1.5M`, `Rp2B`, `Rp3T`, with a decimal point.
        case english

        /// English for an English app language (`en`), Indonesian for everything else: Indonesian is
        /// the source language, the one shown when no translation fits.
        public init(languageCode: String?) {
            self = languageCode == "en" ? .english : .indonesian
        }

        fileprivate var suffixes: [String] {
            switch self {
            case .indonesian: ["rb", "jt", "M", "T"]
            case .english: ["K", "M", "B", "T"]
            }
        }

        fileprivate var decimalSeparator: String {
            switch self {
            case .indonesian: ","
            case .english: "."
            }
        }
    }

    /// A short amount for chart axes: `0` → `0`, `500` → `Rp500`, and in Indonesian `250000` → `Rp250rb`,
    /// `1500000` → `Rp1,5jt`, `2000000000` → `Rp2M` (miliar), `3·10¹²` → `Rp3T` (triliun); in English
    /// `Rp250K`, `Rp1.5M`, `Rp2B`, `Rp3T` (D-065). One decimal at most, rounded half up, with no trailing
    /// `,0`; a value that rounds up to 1.000 of a unit moves to the next unit (`999950` → `Rp1jt`).
    /// Deterministic like ``string(from:)``: the caller picks the style, it never reads the device locale.
    public static func compact(_ amount: Int64, style: CompactStyle = .indonesian) -> String {
        if amount == 0 { return "0" }
        let sign = amount < 0 ? "-" : ""
        let magnitude = amount.magnitude
        let divisors: [UInt64] = [1_000, 1_000_000, 1_000_000_000, 1_000_000_000_000]
        if magnitude < 1_000 { return "\(sign)Rp\(magnitude)" }
        var unitIndex = divisors.lastIndex { magnitude >= $0 } ?? 0
        var tenths = roundedTenths(magnitude, divisor: divisors[unitIndex])
        // e.g. 999.950 → 1.000,0rb: say 1jt instead.
        if tenths >= 10_000, unitIndex + 1 < divisors.count {
            unitIndex += 1
            tenths = roundedTenths(magnitude, divisor: divisors[unitIndex])
        }
        let whole = tenths / 10
        let fraction = tenths % 10
        let number = fraction == 0 ? "\(whole)" : "\(whole)\(style.decimalSeparator)\(fraction)"
        return "\(sign)Rp\(number)\(style.suffixes[unitIndex])"
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
