import KemanayaCore
import Testing

struct RupiahFormatterTests {
    @Test(arguments: [
        (Int64(0), "Rp0"),
        (5, "Rp5"),
        (999, "Rp999"),
        (1_000, "Rp1.000"),
        (45_000, "Rp45.000"),
        (100_000, "Rp100.000"),
        (1_250_000, "Rp1.250.000"),
        (-45_000, "-Rp45.000"),
        (-1, "-Rp1"),
    ])
    func formatsWithDotSeparatorAndNoDecimals(amount: Int64, expected: String) {
        #expect(RupiahFormatter.string(from: amount) == expected)
    }

    @Test func extremesDoNotCrash() {
        #expect(RupiahFormatter.string(from: .max) == "Rp9.223.372.036.854.775.807")
        #expect(RupiahFormatter.string(from: .min) == "-Rp9.223.372.036.854.775.808")
    }

    @Test func int64HelperMatchesFormatter() {
        #expect(Int64(1_250_000).rupiahFormatted == "Rp1.250.000")
    }
}

/// Chart axis labels: short Indonesian amounts (rb, jt, M, T).
struct RupiahCompactTests {
    @Test(arguments: [
        (Int64(0), "0"),
        (500, "Rp500"),
        (999, "Rp999"),
        (1_000, "Rp1rb"),
        (1_500, "Rp1,5rb"),
        (250_000, "Rp250rb"),
        (999_949, "Rp999,9rb"),
        (999_950, "Rp1jt"),
        (1_000_000, "Rp1jt"),
        (1_250_000, "Rp1,3jt"),
        (1_240_000, "Rp1,2jt"),
        (12_000_000, "Rp12jt"),
        (2_000_000_000, "Rp2M"),
        (3_000_000_000_000, "Rp3T"),
        (-1_500_000, "-Rp1,5jt"),
    ])
    func compact(amount: Int64, expected: String) {
        #expect(RupiahFormatter.compact(amount) == expected)
    }

    @Test func extremesDoNotTrap() {
        #expect(RupiahFormatter.compact(.max).hasSuffix("T"))
        #expect(RupiahFormatter.compact(.min).hasPrefix("-Rp"))
    }
}
