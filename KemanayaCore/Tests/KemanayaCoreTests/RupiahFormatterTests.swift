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
