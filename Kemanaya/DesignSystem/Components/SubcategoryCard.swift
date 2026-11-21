import KemanayaCore
import SwiftUI

/// A pinned expense subcategory on Home, compact, in three lines (D-068): emoji and name, this month's
/// total, then either a thin budget bar with "sisa Rp…" / "lewat Rp…" when the subcategory has a budget
/// (D-041), or "Bulan lalu Rp…" without one. Neutral wording throughout (D-022).
///
/// Tap runs `action`; long-press shows the context menu. Home passes D-012's full menu,
/// Lihat detail · Ubah · Lepas pin (D-044, D-051, D-062).
/// VoiceOver reads the button as one element: the name, then this month's total and either the budget
/// or last month's total. The menu items are also its accessibility actions, so VoiceOver offers them
/// without a long-press.
struct SubcategoryCard<MenuItems: View>: View {
    let emoji: String
    let name: String
    let tint: CategoryTint
    let thisMonth: Int64
    let lastMonth: Int64
    let budget: BudgetProgress?
    let action: () -> Void
    let menuItems: () -> MenuItems

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) private var minimumBarWidth: CGFloat = 28
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
        self.thisMonth = thisMonth
        self.lastMonth = lastMonth
        self.budget = budget
        self.action = action
        self.menuItems = contextMenu
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: emoji)
                        .font(.title3)
                    Text(verbatim: name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                AmountText(thisMonth, size: .medium)
                footer
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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

    /// The third line: the budget when set, otherwise last month's total.
    @ViewBuilder private var footer: some View {
        let style = RupiahFormatter.CompactStyle(locale: locale)
        if let budget {
            let status = budget.compactStatusText(style: style)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color(tint.secondaryContent))
                .lineLimit(1)
            // Bar and caption share a line where they fit; in a narrow column at large text the caption
            // moves under the bar instead of squeezing it away.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    BudgetMeter(progress: budget, tint: tint, style: .thinBar)
                        .frame(minWidth: minimumBarWidth)
                    status.fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    BudgetMeter(progress: budget, tint: tint, style: .thinBar)
                    // An amount: shrink rather than wrap or cut digits (D-040).
                    status.minimumScaleFactor(0.5)
                }
            }
        } else {
            Text(
                "Bulan lalu \(lastMonth.rupiahShort(style))",
                comment: "Home card's third line when the subcategory has no budget: last month's total in the short format, e.g. 'Bulan lalu Rp240rb' (D-068)."
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color(tint.secondaryContent))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
    }

    /// This month first, then the budget or last month. Neutral: no "better" or "worse" (D-022).
    private var accessibilityValue: String {
        let monthReading = String(
            localized: "\(thisMonth) rupiah bulan ini",
            comment: "VoiceOver value of a Home card or income row, first part: this month's total in whole rupiah."
        )
        guard let budget else {
            return String(
                localized: "subcategoryCard.accessibilityValue.lastMonth",
                defaultValue: "\(monthReading), bulan lalu \(lastMonth) rupiah",
                comment: "VoiceOver value of a Home card without a budget. 1: this month's total, 2: last month's total in whole rupiah. Neutral, never praise or blame. Keep the order."
            )
        }
        return String(
            localized: "subcategoryCard.accessibilityValue.withBudget",
            defaultValue: "\(monthReading), \(budget.accessibilityStatus)",
            comment: "VoiceOver value of a subcategory card with a budget. 1: this month's total, 2: the budget and what is left or over. Keep the order."
        )
    }
}

#Preview {
    HStack(alignment: .top, spacing: 12) {
        VStack(spacing: 12) {
            SubcategoryCard(emoji: "🍚", name: "Makan", tint: .kebutuhan, thisMonth: 1_250_000, lastMonth: 1_400_000) {
            } contextMenu: {
                Button {} label: { Text(verbatim: "Lihat detail") }
            }
            SubcategoryCard(emoji: "🅿️", name: "Parkir", tint: .kebutuhan, thisMonth: 54_000, lastMonth: 61_000, budget: BudgetProgress(spent: 54_000, budget: 100_000)) {
            } contextMenu: {
                Button {} label: { Text(verbatim: "Lihat detail") }
            }
        }
        VStack(spacing: 12) {
            SubcategoryCard(emoji: "☕", name: "Kopi", tint: .keinginan, thisMonth: 310_000, lastMonth: 240_000, budget: BudgetProgress(spent: 310_000, budget: 300_000)) {
            } contextMenu: {
                Button {} label: { Text(verbatim: "Lihat detail") }
            }
        }
    }
    .padding()
    .background(Color(.appBackground))
}
