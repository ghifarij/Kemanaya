import KemanayaCore
import SwiftUI

/// A pinned subcategory on Home (D-012): emoji, name, this month's total and a tiny bar vs last month.
/// Tap runs `action`; long-press shows the context menu (Lihat detail · Edit · Lepas pin), which every card has.
/// VoiceOver reads the button as one element: the name, then this month's total and its direction.
struct SubcategoryCard<MenuItems: View>: View {
    let emoji: String
    let name: String
    let tint: CategoryTint
    let comparison: MonthComparison
    let action: () -> Void
    let menuItems: () -> MenuItems

    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = 14
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    init(
        emoji: String,
        name: String,
        tint: CategoryTint,
        thisMonth: Int64,
        lastMonth: Int64,
        action: @escaping () -> Void,
        @ViewBuilder contextMenu: @escaping () -> MenuItems
    ) {
        self.emoji = emoji
        self.name = name
        self.tint = tint
        self.comparison = MonthComparison(current: thisMonth, previous: lastMonth)
        self.action = action
        self.menuItems = contextMenu
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: emoji)
                    .font(.title)
                Text(verbatim: name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                AmountText(comparison.current, size: .medium)
                ComparisonBars(comparison: comparison, tint: tint)
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color(tint.content))
            .background(Color(tint.surface), in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.springy)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(accessibilityValue))
        .contentShape(.contextMenuPreview, shape)
        .contextMenu { menuItems() }
    }

    /// Neutral wording: totals go up or down, never "better" or "worse" (D-022).
    private var accessibilityValue: String {
        let amount = comparison.current
        return switch comparison.direction {
        case .up: String(
            localized: "\(amount) rupiah bulan ini, naik dibanding bulan lalu",
            comment: "VoiceOver value of a subcategory card: this month's total in whole rupiah, higher than last month. Keep it neutral, never praise or blame."
        )
        case .down: String(
            localized: "\(amount) rupiah bulan ini, turun dibanding bulan lalu",
            comment: "VoiceOver value of a subcategory card: this month's total in whole rupiah, lower than last month. Keep it neutral, never praise or blame."
        )
        case .same: String(
            localized: "\(amount) rupiah bulan ini, sama dengan bulan lalu",
            comment: "VoiceOver value of a subcategory card: this month's total in whole rupiah, equal to last month."
        )
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        SubcategoryCard(emoji: "🍚", name: "Makan", tint: .kebutuhan, thisMonth: 1_250_000, lastMonth: 1_400_000) {
        } contextMenu: {
            Button {} label: { Text(verbatim: "Lihat detail") }
        }
        SubcategoryCard(emoji: "☕", name: "Kopi", tint: .keinginan, thisMonth: 310_000, lastMonth: 240_000) {
        } contextMenu: {
            Button {} label: { Text(verbatim: "Lihat detail") }
        }
        SubcategoryCard(emoji: "💼", name: "Gaji", tint: .pemasukan, thisMonth: 8_500_000, lastMonth: 8_500_000) {
        } contextMenu: {
            Button {} label: { Text(verbatim: "Lihat detail") }
        }
    }
    .padding()
    .background(Color(.appBackground))
}
