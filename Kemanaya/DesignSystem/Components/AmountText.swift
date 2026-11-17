import KemanayaCore
import SwiftUI

/// A rupiah amount in the brand amount type (D-016, D-022).
///
/// Never truncates digits: it stays on one line and shrinks to fit instead. An amount split
/// across lines ("Rp1.250." / "000") reads as two numbers, and an ellipsis would hide digits,
/// so scaling is the safest choice for money. Layouts give amounts the full width at
/// accessibility sizes (e.g. a one-column grid), so the shrink only kicks in at the extremes.
/// The color comes from the environment's foreground style; callers pick a high-contrast token.
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

    init(_ amount: Int64, size: Size = .medium) {
        self.amount = amount
        self.size = size
    }

    var body: some View {
        Text(verbatim: amount.rupiahFormatted)
            .font(size.font)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .allowsTightening(true)
            .accessibilityLabel(Text(
                "\(amount) rupiah",
                comment: "VoiceOver reading of a money amount. The number is whole rupiah, without separators."
            ))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AmountText(1_250_000, size: .hero)
        AmountText(1_250_000, size: .large)
        AmountText(45_000, size: .medium)
        AmountText(-45_000, size: .small)
        AmountText(.max, size: .large)
    }
    .padding()
    .foregroundStyle(Color(.textPrimary))
    .background(Color(.appBackground))
}
