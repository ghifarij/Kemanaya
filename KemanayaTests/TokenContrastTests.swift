import KemanayaCore
import Testing
import UIKit
@testable import Kemanaya

/// Proves that every color pair the design system draws meets WCAG AA (D-022),
/// resolving the real asset-catalog colors under each appearance.
@MainActor
struct TokenContrastTests {
    enum Appearance: String, CaseIterable, Sendable {
        case light, dark, lightHighContrast, darkHighContrast

        @MainActor var traits: UITraitCollection {
            UITraitCollection { traits in
                traits.userInterfaceStyle = (self == .dark || self == .darkHighContrast) ? .dark : .light
                traits.accessibilityContrast = isHighContrast ? .high : .normal
            }
        }

        var isHighContrast: Bool { self == .lightHighContrast || self == .darkHighContrast }
    }

    enum Use {
        /// Text: ≥ 4.5:1, ≥ 7:1 with Increase Contrast.
        case text
        /// Bars and other data marks against their background: ≥ 3:1.
        case nonText
        /// Two marks drawn side by side as different series: they must differ in lightness, not only
        /// in hue, so colour-blind users can tell them apart (D-055).
        case adjacentMarks

        /// Lightness gap required between ``adjacentMarks`` (WCAG ratio formula).
        static let adjacentMarksRatio = 1.6

        func minimumRatio(highContrast: Bool) -> Double {
            switch self {
            case .text: highContrast ? ContrastRatio.enhancedText : ContrastRatio.normalText
            case .nonText: ContrastRatio.nonText
            case .adjacentMarks: Self.adjacentMarksRatio
            }
        }
    }

    struct Pair {
        let name: String
        let foreground: ColorResource
        let background: ColorResource
        let use: Use
    }

    /// The pairs components actually draw. Card pairs come from `CategoryTint`, so changing
    /// the mapping there is tested automatically.
    static var usedPairs: [Pair] {
        var pairs: [Pair] = []
        // Screen text, SplitBar legend, keypad keys and accent-tinted controls.
        for (bgName, background) in [("appBackground", ColorResource.appBackground), ("surface", .surface)] {
            pairs.append(Pair(name: "textPrimary on \(bgName)", foreground: .textPrimary, background: background, use: .text))
            pairs.append(Pair(name: "textSecondary on \(bgName)", foreground: .textSecondary, background: background, use: .text))
            pairs.append(Pair(name: "brand on \(bgName)", foreground: .brand, background: background, use: .text))
            // SplitBar segments and legend dots, read through CategoryTint exactly as SplitBar does.
            for tint in [CategoryTint.kebutuhan, .keinginan] {
                pairs.append(Pair(name: "\(tint) bar on \(bgName)", foreground: tint.bar, background: background, use: .nonText))
            }
            // Analisis charts (D-051): group and income marks, and the neutral pengeluaran bar (D-055).
            for tint in CategoryTint.allCases {
                pairs.append(Pair(name: "\(tint) chartMark on \(bgName)", foreground: tint.chartMark, background: background, use: .nonText))
            }
            pairs.append(Pair(name: "chartNeutral on \(bgName)", foreground: .chartNeutral, background: background, use: .nonText))
        }
        // The Anggaran sheet's add marks (D-080): "Atur" (text) and `plus.circle` in the group's bar colour,
        // on the list's `surface` rows.
        for tint in [CategoryTint.kebutuhan, .keinginan] {
            pairs.append(Pair(name: "\(tint) bar as text on surface", foreground: tint.bar, background: .surface, use: .text))
        }
        // The six-month chart pairs a pengeluaran bar with a pemasukan bar in every month (D-055).
        pairs.append(Pair(
            name: "chartNeutral beside pemasukan chartMark",
            foreground: .chartNeutral,
            background: CategoryTint.pemasukan.chartMark,
            use: .adjacentMarks
        ))
        // Subcategory cards: name and amount; last-month bar (held to the text bar); this-month bar.
        for tint in CategoryTint.allCases {
            pairs.append(Pair(name: "\(tint) content on surface", foreground: tint.content, background: tint.surface, use: .text))
            pairs.append(Pair(name: "\(tint) secondaryContent on surface", foreground: tint.secondaryContent, background: tint.surface, use: .text))
            pairs.append(Pair(name: "\(tint) bar on surface", foreground: tint.bar, background: tint.surface, use: .nonText))
        }
        return pairs
    }

    @Test(arguments: Appearance.allCases)
    func usedPairsMeetWCAG(appearance: Appearance) {
        for pair in Self.usedPairs {
            let ratio = ContrastRatio.between(
                Self.resolve(pair.foreground, appearance),
                Self.resolve(pair.background, appearance)
            )
            let minimum = pair.use.minimumRatio(highContrast: appearance.isHighContrast)
            #expect(ratio >= minimum, "\(pair.name) in \(appearance.rawValue): \(ratio) < \(minimum)")
        }
    }

    /// D-022 fixes the light base hexes.
    @Test func lightBaseColorsMatchTheBrand() {
        #expect(Self.resolve(.brand, .light) == SRGBColor(hex: 0x6C3BFF))
        #expect(Self.resolve(.kebutuhan, .light) == SRGBColor(hex: 0x6C3BFF))
        #expect(Self.resolve(.keinginan, .light) == SRGBColor(hex: 0xFF5A5F))
        #expect(Self.resolve(.pemasukan, .light) == SRGBColor(hex: 0xC6F432))
    }

    /// Guards the test itself: each appearance must resolve to its own variant.
    @Test func traitsSelectEachVariant() {
        #expect(Self.resolve(.textPrimary, .light) == SRGBColor(hex: 0x1B1A1F))
        #expect(Self.resolve(.textPrimary, .dark) == SRGBColor(hex: 0xF6F3EE))
        #expect(Self.resolve(.textPrimary, .lightHighContrast) == SRGBColor(hex: 0x000000))
        #expect(Self.resolve(.textPrimary, .darkHighContrast) == SRGBColor(hex: 0xFFFFFF))
    }

    /// `CategoryTint` builds its resources by name; they must match the generated symbols.
    @Test func tintResourcesMatchGeneratedSymbols() {
        #expect(CategoryTint.kebutuhan.surface == .kebutuhanSurface)
        #expect(CategoryTint.keinginan.surface == .keinginanSurface)
        #expect(CategoryTint.pemasukan.surface == .pemasukanSurface)
        #expect(CategoryTint.kebutuhan.content == .textPrimary)
        #expect(CategoryTint.keinginan.content == .textPrimary)
        #expect(CategoryTint.pemasukan.content == .onPemasukan)
        #expect(CategoryTint.kebutuhan.secondaryContent == .textSecondary)
        #expect(CategoryTint.keinginan.secondaryContent == .textSecondary)
        #expect(CategoryTint.pemasukan.secondaryContent == .onPemasukan)
        #expect(CategoryTint.kebutuhan.bar == .kebutuhanStrong)
        #expect(CategoryTint.keinginan.bar == .keinginanStrong)
        #expect(CategoryTint.pemasukan.bar == .pemasukanStrong)
        #expect(CategoryTint.kebutuhan.chartMark == .kebutuhanStrong)
        #expect(CategoryTint.keinginan.chartMark == .keinginanStrong)
        #expect(CategoryTint.pemasukan.chartMark == .pemasukanChart)
    }

    /// Keypad keys and containers sit on `surface`; it must never melt into the background,
    /// including with Increase Contrast.
    @Test(arguments: Appearance.allCases)
    func surfaceDiffersFromBackground(appearance: Appearance) {
        #expect(Self.resolve(.surface, appearance) != Self.resolve(.appBackground, appearance))
    }

    @Test func accentColorMatchesBrand() throws {
        let accent = try #require(UIColor(named: "AccentColor", in: .main, compatibleWith: nil))
        for appearance in Appearance.allCases {
            #expect(Self.components(of: accent, appearance) == Self.resolve(.brand, appearance))
        }
    }

    private static func resolve(_ resource: ColorResource, _ appearance: Appearance) -> SRGBColor {
        components(of: UIColor(resource: resource), appearance)
    }

    /// Asset colors are sRGB and opaque, so the sRGB components are exact (to 8-bit rounding).
    private static func components(of color: UIColor, _ appearance: Appearance) -> SRGBColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.resolvedColor(with: appearance.traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        // Extended sRGB: a wide-gamut (Display P3) color would land outside 0...1 here.
        // Clamping it would make the contrast math lie, so fail instead.
        for component in [red, green, blue] {
            #expect((0...1).contains(component), "Color is outside sRGB; keep color sets in sRGB")
        }
        #expect(alpha == 1, "Color tokens must be opaque")
        let rounded = { (value: CGFloat) in Double((value * 255).rounded()) / 255 }
        return SRGBColor(red: rounded(red), green: rounded(green), blue: rounded(blue))
    }
}
