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

/// Chart axis labels: short amounts in the app language, Indonesian (rb, jt, M, T) or English (K, M, B, T).
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
        #expect(RupiahFormatter.compact(.max, style: .english).hasSuffix("T"))
        #expect(RupiahFormatter.compact(.min, style: .english).hasPrefix("-Rp"))
    }

    /// The same amounts with the Indonesian style named, as the app passes it for `id` (D-065).
    @Test func indonesianIsTheDefault() {
        for amount: Int64 in [0, 999, 1_500, 250_000, 999_950, 1_250_000, 2_000_000_000, -1_500_000] {
            #expect(RupiahFormatter.compact(amount, style: .indonesian) == RupiahFormatter.compact(amount))
        }
    }

    /// English abbreviations with a decimal point (D-065): K, M, B, T. The rupiah prefix stays.
    @Test(arguments: [
        (Int64(0), "0"),
        (500, "Rp500"),
        (999, "Rp999"),
        (1_000, "Rp1K"),
        (1_500, "Rp1.5K"),
        (250_000, "Rp250K"),
        (999_949, "Rp999.9K"),
        (999_950, "Rp1M"),
        (1_000_000, "Rp1M"),
        (1_250_000, "Rp1.3M"),
        (1_500_000, "Rp1.5M"),
        (12_000_000, "Rp12M"),
        (2_000_000_000, "Rp2B"),
        (3_000_000_000_000, "Rp3T"),
        (-1_500_000, "-Rp1.5M"),
    ])
    func compactInEnglish(amount: Int64, expected: String) {
        #expect(RupiahFormatter.compact(amount, style: .english) == expected)
    }

    /// The app language picks the style: English for `en`, Indonesian otherwise (the source language).
    @Test func styleFollowsTheLanguage() {
        #expect(RupiahFormatter.CompactStyle(languageCode: "en") == .english)
        #expect(RupiahFormatter.CompactStyle(languageCode: "id") == .indonesian)
        #expect(RupiahFormatter.CompactStyle(languageCode: nil) == .indonesian)
        #expect(RupiahFormatter.CompactStyle(languageCode: "fr") == .indonesian)
    }
}
