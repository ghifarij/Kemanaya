import KemanayaCore
import SwiftUI

/// One transaction row, in Riwayat (D-053) and the subcategory detail (D-051): emoji, subcategory,
/// note, date and time, amount. Under a day header (Riwayat) it shows the time only.
/// Amounts are always `textPrimary`; income is told apart by its `+` sign, never by a vivid color (D-040).
/// VoiceOver reads the row as one element; the swipe actions appear in its actions rotor.
struct TransactionRow: View {
    let transaction: MoneyTransaction
    /// False under a day header, which already names the day: the row then shows only the time.
    var showsDay = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            HStack(alignment: .top, spacing: 12) {
                Text(verbatim: transaction.displayEmoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: transaction.displayName)
                        .font(.body.weight(.semibold))
                    if let note = transaction.note {
                        Text(verbatim: note)
                            .font(.subheadline)
                            .foregroundStyle(Color(.textSecondary))
                            .lineLimit(2)
                    }
                    Text(transaction.date, format: dateFormat)
                        .font(.caption)
                        .foregroundStyle(Color(.textSecondary))
                }
            }
            if !isLarge {
                Spacer(minLength: 8)
            }
            AmountText(transaction.amount, size: .small, showsPlusSign: transaction.kind == .income)
                .layoutPriority(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var dateFormat: Date.FormatStyle {
        let format = Date.FormatStyle.gregorian(locale: locale)
        return showsDay ? format.day().month(.abbreviated).hour().minute() : format.hour().minute()
    }
}
