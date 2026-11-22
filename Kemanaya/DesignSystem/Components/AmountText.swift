import KemanayaCore
import SwiftUI

/// A rupiah amount in the brand amount type (D-016, D-022).
///
/// Never truncates digits: it stays on one line and shrinks to fit instead. An amount split
/// across lines ("Rp1.250." / "000") reads as two numbers, and an ellipsis would hide digits,
/// so scaling is the safest choice for money. Layouts give amounts the full width at
/// accessibility sizes (e.g. a one-column grid), so the shrink only kicks in at the extremes.
/// The color comes from the environment's foreground style; callers pick a high-contrast token.
/// Income in lists shows an explicit plus (`+Rp5.000.000`); the sign, not a color, tells the direction (D-040).
struct AmountText: View {
    enum Size {
        case hero, large, medium, small

        var font: Font {
            switch self {
            case .hero: .amountHero
            case .large: .amountLarge
            case .medium: .amountMedium
            case .small: .amountSmall
            }
        }
    }

    let amount: Int64
    let size: Size
    let showsPlusSign: Bool

    /// - Parameter showsPlusSign: prefix positive amounts with `+`, e.g. income rows.
    init(_ amount: Int64, size: Size = .medium, showsPlusSign: Bool = false) {
        self.amount = amount
        self.size = size
        self.showsPlusSign = showsPlusSign
    }

    private var hasPlus: Bool { showsPlusSign && amount > 0 }

    var body: some View {
        Text(verbatim: (hasPlus ? "+" : "") + amount.rupiahFormatted)
            .font(size.font)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .allowsTightening(true)
            .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: Text {
        if hasPlus {
            Text(
                "+\(amount) rupiah",
                comment: "VoiceOver reading of an incoming money amount (income), read as 'plus'. The number is whole rupiah, without separators."
            )
        } else {
            Text(
                "\(amount) rupiah",
                comment: "VoiceOver reading of a money amount. The number is whole rupiah, without separators."
            )
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AmountText(1_250_000, size: .hero)
        AmountText(1_250_000, size: .large)
        AmountText(45_000, size: .medium)
        AmountText(-45_000, size: .small)
        AmountText(8_500_000, size: .small, showsPlusSign: true)
        AmountText(.max, size: .large)
    }
    .padding()
    .foregroundStyle(Color(.textPrimary))
    .background(Color(.appBackground))
}

extension Int64 {
    /// This amount as a short label for cards and the Home hero (D-068): `Rp240rb`, `Rp1,4jt`, and `Rp0`
    /// for nothing (``RupiahFormatter/compact(_:style:)`` gives a bare `0`, which suits chart axes only).
    func rupiahShort(_ style: RupiahFormatter.CompactStyle) -> String {
        self == 0 ? rupiahFormatted : RupiahFormatter.compact(self, style: style)
    }
}

extension RupiahFormatter.CompactStyle {
    /// The short amount style for the app language (D-065): English abbreviations for English, Indonesian otherwise.
    init(locale: Locale) {
        self.init(languageCode: locale.language.languageCode?.identifier)
    }
}
