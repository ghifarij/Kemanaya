import KemanayaCore
import SwiftUI

/// A pinned subcategory on Home (D-012): emoji, name, this month's total and a tiny bar vs last month,
/// plus a budget ring and caption only when the subcategory has a budget (D-041, D-048).
/// Tap runs `action`; long-press shows the context menu. Phase 5 Home passes only "Lepas pin" (D-048);
/// D-012's full menu (Lihat detail · Ubah · Lepas pin, D-044) is the end state.
/// VoiceOver reads the button as one element: the name, then this month's total, its direction and the
/// budget. The menu items are also its accessibility actions, so VoiceOver offers them without a long-press.
struct SubcategoryCard<MenuItems: View>: View {
    let emoji: String
    let name: String
    let tint: CategoryTint
    let comparison: MonthComparison
    let budget: BudgetProgress?
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
        budget: BudgetProgress? = nil,
        action: @escaping () -> Void,
        @ViewBuilder contextMenu: @escaping () -> MenuItems
    ) {
        self.emoji = emoji
        self.name = name
        self.tint = tint
        self.comparison = MonthComparison(current: thisMonth, previous: lastMonth)
        self.budget = budget
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
                if let budget {
                    HStack(spacing: 6) {
                        BudgetMeter(progress: budget, tint: tint, style: .ring)
                        budget.statusText
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color(tint.secondaryContent))
                            // An amount: shrink rather than wrap or cut digits (D-040).
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            .padding(padding)
            // Fills its grid cell, so cards in a row match the tallest one (e.g. one with a budget).
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(Color(tint.content))
            .background(Color(tint.surface), in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.springy)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(accessibilityValue))
        .contentShape(.contextMenuPreview, shape)
        .contextMenu { menuItems() }
        .accessibilityActions { menuItems() }
    }

    /// Neutral wording: totals go up or down, never "better" or "worse" (D-022).
    private var accessibilityValue: String {
        guard let budget else { return monthReading }
        return String(
            localized: "subcategoryCard.accessibilityValue.withBudget",
            defaultValue: "\(monthReading), \(budget.accessibilityStatus)",
            comment: "VoiceOver value of a subcategory card with a budget. 1: this month's total and direction, 2: the budget and what is left or over. Keep the order."
        )
    }

    private var monthReading: String {
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
        SubcategoryCard(emoji: "☕", name: "Kopi", tint: .keinginan, thisMonth: 310_000, lastMonth: 240_000, budget: BudgetProgress(spent: 310_000, budget: 300_000)) {
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
