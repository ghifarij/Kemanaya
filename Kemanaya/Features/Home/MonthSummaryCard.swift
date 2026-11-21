import KemanayaCore
import SwiftUI

/// Home's hero (D-068): the month's title with a chevron, the month's total spending ("terpakai bulan
/// ini"), then one row each for Kebutuhan and Keinginan: spent of the group budget with a bar when a
/// budget is set (D-041), otherwise the group's share of spending. No income, sisa or savings rate.
/// A month with nothing logged shows a calm Si Naya note instead (D-063), plus any group budget already set.
///
/// The whole hero is one button that opens this month's transactions (`action`). Numbers only, no
/// verdicts (D-022): over budget keeps the group's Strong colour and says "Lewat Rp…" plainly (D-050).
///
/// `emptyAccessory` sits under the empty note, outside the button so it stays tappable on its own, e.g.
/// Home's "Pulihkan dari cadangan" on a fresh install (D-060).
struct MonthSummaryCard: View {
    let overview: HomeOverview
    /// "November 2026".
    let title: String
    let action: () -> Void
    /// Type-erased: the card has static members, which a generic view can't have.
    private let emptyAccessory: AnyView?

    init(overview: HomeOverview, title: String, action: @escaping () -> Void) {
        self.overview = overview
        self.title = title
        self.action = action
        emptyAccessory = nil
    }

    init(overview: HomeOverview, title: String, action: @escaping () -> Void, @ViewBuilder emptyAccessory: () -> some View) {
        self.overview = overview
        self.title = title
        self.action = action
        self.emptyAccessory = AnyView(emptyAccessory())
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 14) {
                    titleRow
                    if overview.isEmpty {
                        emptyState
                    } else {
                        total
                    }
                    ForEach(visibleGroups) { row in
                        GroupRowView(row: row)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(HeroPressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityValue(Text(accessibilityValue))
            .accessibilityHint(Text(
                "Membuka transaksi bulan ini.",
                comment: "VoiceOver hint on Home's month summary: tapping it opens this month's transactions (D-068)."
            ))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.hero")

            if overview.isEmpty, let emptyAccessory {
                emptyAccessory
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Rows

    /// Both groups once something is logged; in an empty month only those with a budget, so a budget set
    /// before the first entry still shows (D-048).
    private var visibleGroups: [HomeOverview.GroupRow] {
        overview.isEmpty ? overview.groups.filter { $0.budget != nil } : overview.groups
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
        }
    }

    private var total: some View {
        VStack(alignment: .leading, spacing: 2) {
            AmountText(overview.month.expenses, size: .large)
            Text("terpakai bulan ini", comment: "Home hero: caption under this month's total spending (D-068).")
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Empty

    /// Nothing logged this month: Si Naya, calm, and a pointer to the cards and "+", never a verdict
    /// (D-022, D-063). The cards below still show.
    private var emptyState: some View {
        // Si Naya sits beside the text, or above it at accessibility sizes so the text keeps the width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        return layout {
            EmptyStateMascot(mood: .calm, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.emptyTitle)
                    .font(.headline)
                Text(Self.emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private static let emptyTitle = LocalizedStringResource(
        "Bulan ini masih kosong",
        comment: "Home empty state title: nothing logged this month yet."
    )

    private static let emptyMessage = LocalizedStringResource(
        "Ketuk kartu di bawah atau + untuk mencatat pengeluaran atau pemasukan.",
        comment: "Home empty state description: tap a card below or + to log an expense or income."
    )

    // MARK: - VoiceOver

    /// The empty note, or the total and each group's row, in whole rupiah.
    private var accessibilityValue: String {
        let groups = visibleGroups.map(Self.accessibilityReading)
        guard !overview.isEmpty else {
            let note = "\(String(localized: Self.emptyTitle)). \(String(localized: Self.emptyMessage))"
            return ([note] + groups).joined(separator: " ")
        }
        let total = String(
            localized: "terpakai \(overview.month.expenses) rupiah bulan ini",
            comment: "VoiceOver value of Home's hero, first part: this month's total spending in whole rupiah (D-068)."
        )
        return ([total] + groups).joined(separator: ", ")
    }

    private static func accessibilityReading(_ row: HomeOverview.GroupRow) -> String {
        let group = String(localized: row.group.title)
        if let budget = row.budget {
            return String(
                localized: "home.hero.group.budget",
                defaultValue: "\(group) \(row.spent) rupiah, \(budget.accessibilityStatus)",
                comment: "VoiceOver: a group's row in Home's hero with a budget. 1: Kebutuhan or Keinginan, 2: spent in whole rupiah, 3: the budget and what is left or over. Keep the order."
            )
        }
        return String(
            localized: "home.hero.group.share",
            defaultValue: "\(group) \(row.spent) rupiah, \(row.sharePercent) persen dari pengeluaran",
            comment: "VoiceOver: a group's row in Home's hero without a budget. 1: Kebutuhan or Keinginan, 2: spent in whole rupiah, 3: its share of this month's spending in percent."
        )
    }
}

/// One group in the hero: the name, "Rp3,1jt / Rp4jt" (spent / budget) or "Rp3,1jt · 73%" (spent and share),
/// a bar in the group's Strong colour, and "Lewat Rp…" under it only when over budget (D-050, D-068).
private struct GroupRowView: View {
    let row: HomeOverview.GroupRow

    @Environment(\.locale) private var locale

    var body: some View {
        let tint = CategoryTint(kind: .expense, group: row.group)
        VStack(alignment: .leading, spacing: 6) {
            // One line when the figures fit at full size; otherwise they go under the name and may shrink,
            // never cut digits (D-040).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    name
                    Spacer(minLength: 0)
                    figures.fixedSize()
                }
                VStack(alignment: .leading, spacing: 2) {
                    name
                    figures.minimumScaleFactor(0.5)
                }
            }
            MeterBar(fraction: row.barFraction, tint: tint)
            if let budget = row.budget, budget.isOverBudget {
                budget.statusText
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    private var name: some View {
        Text(row.group.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var figures: some View {
        let style = RupiahFormatter.CompactStyle(locale: locale)
        let spent = row.spent.rupiahShort(style)
        let text = if let budget = row.budget {
            "\(spent) / \(budget.budget.rupiahShort(style))"
        } else {
            "\(spent) · \((Double(row.sharePercent) / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale)))"
        }
        return Text(verbatim: text)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Color(.textSecondary))
            .lineLimit(1)
    }
}

/// The hero's press: it dims a little while held, without moving the card's surface.
private struct HeroPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    let id = UUID()
    let current = [
        TransactionSnapshot(amount: 1_344_000, kind: .expense, group: .kebutuhan, subcategoryID: id, date: .now),
        TransactionSnapshot(amount: 431_500, kind: .expense, group: .keinginan, subcategoryID: UUID(), date: .now),
        TransactionSnapshot(amount: 8_500_000, kind: .income, group: nil, subcategoryID: UUID(), date: .now),
    ]
    ScrollView {
        VStack(spacing: 16) {
            MonthSummaryCard(
                overview: HomeOverview(current: current, previous: [], pins: [], groupBudgets: [.kebutuhan: 3_000_000, .keinginan: 400_000]),
                title: "November 2026"
            ) {}
            MonthSummaryCard(
                overview: HomeOverview(current: current, previous: [], pins: [], groupBudgets: [:]),
                title: "November 2026"
            ) {}
            MonthSummaryCard(overview: HomeOverview(current: [], previous: [], pins: [], groupBudgets: [:]), title: "November 2026") {}
        }
        .padding()
    }
    .foregroundStyle(Color(.textPrimary))
    .background(Color(.appBackground))
}
