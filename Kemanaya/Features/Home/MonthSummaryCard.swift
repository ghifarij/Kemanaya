import KemanayaCore
import SwiftUI

/// Home's hero (D-068, D-073, D-074), compact: a caption "Pengeluaran November 2026" with a chevron, the
/// month's total spending under it, then one split bar of Kebutuhan (Strong colour, from the left) and
/// Keinginan (from the right), as wide as each group's share of the month's spending. Under the bar a
/// legend names each group with a colour dot and its amount, Kebutuhan leading and Keinginan trailing
/// (stacked at accessibility sizes), money only: the bar already shows the ratio. No budget captions
/// (D-074), no income, savings rate or percentages. A month with nothing logged shows a calm Si Naya note
/// instead (D-063), never the bar.
///
/// The whole hero is one button that opens this month's transactions (`action`). Numbers only, no
/// verdicts (D-022).
///
/// `emptyAccessory` sits under the empty note, outside the button so it stays tappable on its own, e.g.
/// Home's "Pulihkan dari cadangan" on a fresh install (D-060).
///
/// While Kebutuhan or Keinginan has no budget, a quiet "Atur anggaran" link sits at the card's bottom
/// right, also outside the button, empty month or not: it runs `onSetBudget`, which opens Atur kartu (D-069).
struct MonthSummaryCard: View {
    let overview: HomeOverview
    /// "November 2026".
    let title: String
    let action: () -> Void
    /// The "Atur anggaran" link's action; nil hides the link.
    let onSetBudget: (() -> Void)?
    /// Type-erased: the card has static members, which a generic view can't have.
    private let emptyAccessory: AnyView?

    init(overview: HomeOverview, title: String, action: @escaping () -> Void, onSetBudget: (() -> Void)? = nil) {
        self.overview = overview
        self.title = title
        self.action = action
        self.onSetBudget = onSetBudget
        emptyAccessory = nil
    }

    init(
        overview: HomeOverview,
        title: String,
        action: @escaping () -> Void,
        onSetBudget: (() -> Void)? = nil,
        @ViewBuilder emptyAccessory: () -> some View
    ) {
        self.overview = overview
        self.title = title
        self.action = action
        self.onSetBudget = onSetBudget
        self.emptyAccessory = AnyView(emptyAccessory())
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        captionRow
                        if !overview.isEmpty {
                            AmountText(overview.month.expenses, size: .medium)
                        }
                    }
                    if overview.isEmpty {
                        emptyState
                    }
                    if showsSplit {
                        split
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, buttonBottomPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(HeroPressStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: heroTitle))
            .accessibilityValue(Text(accessibilityValue))
            .accessibilityHint(Text(
                "Membuka transaksi bulan ini.",
                comment: "VoiceOver hint on Home's month summary: tapping it opens this month's transactions (D-068)."
            ))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.hero")

            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    /// The empty month's accessory, shown under the button.
    private var footerAccessory: AnyView? {
        overview.isEmpty ? emptyAccessory : nil
    }

    /// Whether the "Atur anggaran" link shows: a group without a budget, and somewhere to set one.
    private var showsBudgetLink: Bool {
        onSetBudget != nil && overview.groups.contains(where: { $0.budget == nil })
    }

    /// The button's own bottom padding. With only the link under it, the button keeps 4 pt: the link's
    /// 44 pt tap area already gives the card its bottom room, so the link sits close to the last row
    /// without overlapping the button.
    private var buttonBottomPadding: CGFloat {
        showsBudgetLink && footerAccessory == nil ? 4 : 14
    }

    /// Under the button: the empty month's accessory and the "Atur anggaran" link, side by side while they
    /// fit, otherwise stacked.
    @ViewBuilder private var footer: some View {
        let accessory = footerAccessory
        let link = showsBudgetLink ? onSetBudget.map(budgetLink) : nil
        if accessory != nil || link != nil {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    accessory
                    Spacer(minLength: 0)
                    link?.fixedSize()
                }
                VStack(alignment: .leading, spacing: 0) {
                    accessory
                    link?.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, accessory == nil ? 4 : 12)
        }
    }

    /// "Atur anggaran", small and in the brand tint; its own button and VoiceOver element, so it never
    /// opens the month (D-069).
    private func budgetLink(_ onSetBudget: @escaping () -> Void) -> some View {
        Button(action: onSetBudget) {
            Text(BudgetCopy.setBudget)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.brand))
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(
            "Membuka Atur kartu untuk mengatur anggaran.",
            comment: "VoiceOver hint on the 'Atur anggaran' link on Home's hero: it opens Atur kartu, where group and subcategory budgets are set (D-069)."
        ))
        .accessibilityIdentifier("home.setBudget")
    }

    // MARK: - Split

    /// The split bar and legend once something is logged (D-074): an empty month shows only its note.
    private var showsSplit: Bool {
        !overview.isEmpty
    }

    /// "Pengeluaran November 2026": what the total under it is (D-073).
    private var heroTitle: String {
        String(
            localized: "home.hero.title",
            defaultValue: "Pengeluaran \(title)",
            comment: "Home hero: the caption above this month's total spending, e.g. 'Pengeluaran November 2026' (D-073). Also its VoiceOver label. The placeholder is the month and year."
        )
    }

    private var captionRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: heroTitle)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
        }
    }

    /// The bar, then the legend: side by side, each item at its natural width with a flexible gap
    /// between, while both fit whole; otherwise (and always at the accessibility sizes) stacked, needs
    /// first. Text is never truncated.
    private var split: some View {
        let groups = overview.groups
        let share = SplitShare(first: overview.month.kebutuhan, second: overview.month.keinginan)
        return VStack(alignment: .leading, spacing: 8) {
            SplitTrack(share: share, height: barHeight)
            if dynamicTypeSize.isAccessibilitySize {
                stackedLegend(groups)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(groups) { row in
                            LegendItem(row: row, isStacked: false)
                            if row.group == .kebutuhan {
                                Spacer(minLength: 12)
                            }
                        }
                    }
                    stackedLegend(groups)
                }
            }
        }
    }

    private func stackedLegend(_ groups: [HomeOverview.GroupRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(groups) { row in
                LegendItem(row: row, isStacked: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
            EmptyStateMascot(mood: .calm, size: 40)
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

    /// The empty note, or the total, then each group with its amount and share, in whole rupiah (D-074:
    /// no budget part).
    private var accessibilityValue: String {
        guard !overview.isEmpty else {
            return "\(String(localized: Self.emptyTitle)). \(String(localized: Self.emptyMessage))"
        }
        let groups = overview.groups.map(Self.accessibilityReading)
        let total = String(
            localized: "home.hero.total",
            defaultValue: "\(overview.month.expenses) rupiah",
            comment: "VoiceOver value of Home's hero, first part: this month's total spending in whole rupiah, read after the label 'Pengeluaran November 2026' (D-073)."
        )
        return ([total] + groups).joined(separator: ", ")
    }

    private static func accessibilityReading(_ row: HomeOverview.GroupRow) -> String {
        let group = String(localized: row.group.title)
        return String(
            localized: "home.hero.group.share",
            defaultValue: "\(group) \(row.spent) rupiah, \(row.sharePercent) persen",
            comment: "VoiceOver: a group in Home's hero (D-073, D-074). 1: Kebutuhan or Keinginan, 2: spent in whole rupiah, 3: its share of this month's spending in percent."
        )
    }
}

/// One group in the hero's legend (D-073, D-074): a dot in the group's Strong colour, the name and its
/// amount in the short format ("● Kebutuhan Rp3,1jt"), nothing else. Name and amount share a line while
/// they fit; otherwise the amount goes under the name and may shrink, never cut digits (D-040).
private struct LegendItem: View {
    let row: HomeOverview.GroupRow
    /// Side by side (false), every text keeps its full width so the legend's fit check sees it; stacked
    /// (true), the item has the row's width and the amount may go under the name.
    let isStacked: Bool

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .subheadline) private var dotSize: CGFloat = 8

    var body: some View {
        let style = RupiahFormatter.CompactStyle(locale: locale)
        if isStacked {
            ViewThatFits(in: .horizontal) {
                line(style)
                VStack(alignment: .leading, spacing: 0) {
                    name
                    // An amount: shrink rather than wrap or cut digits (D-040).
                    amount(style).lineLimit(1).minimumScaleFactor(0.5)
                }
            }
        } else {
            line(style)
        }
    }

    /// "● Kebutuhan Rp3,1jt" on one line, at full width.
    private func line(_ style: RupiahFormatter.CompactStyle) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            name
            amount(style).fixedSize()
        }
    }

    private var name: some View {
        HStack(alignment: .center, spacing: 6) {
            Circle()
                .fill(Color(CategoryTint(kind: .expense, group: row.group).bar))
                .frame(width: dotSize, height: dotSize)
            Text(row.group.title)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize()
        }
    }

    private func amount(_ style: RupiahFormatter.CompactStyle) -> Text {
        Text(verbatim: row.spent.rupiahShort(style))
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color(.textPrimary))
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

private struct HeroPreviewCase: Identifiable {
    let name: String
    let kebutuhan: Int64
    let keinginan: Int64
    /// Budgets no longer show in the hero (D-074); they only hide the "Atur anggaran" link.
    var budgets: [ExpenseGroup: Int64] = [:]

    var id: String { name }

    var overview: HomeOverview {
        let current = [
            TransactionSnapshot(amount: kebutuhan, kind: .expense, group: .kebutuhan, subcategoryID: UUID(), date: .now),
            TransactionSnapshot(amount: keinginan, kind: .expense, group: .keinginan, subcategoryID: UUID(), date: .now),
        ].filter { $0.amount > 0 }
        return HomeOverview(current: current, previous: [], pins: [], groupBudgets: budgets)
    }
}

/// The hero cases side by side in a scroll view, each under its name.
private struct HeroPreviewList: View {
    let cases: [HeroPreviewCase]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(cases) { item in
                    Text(verbatim: item.name).font(.caption)
                    MonthSummaryCard(overview: item.overview, title: "November 2026", action: {}, onSetBudget: {}) {
                        Label {
                            Text(verbatim: "Pulihkan dari cadangan")
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.brand))
                        .frame(minHeight: 44)
                    }
                }
            }
            .padding()
        }
        .foregroundStyle(Color(.textPrimary))
        .background(Color(.appBackground))
    }
}

#Preview("Split") {
    HeroPreviewList(cases: [
        HeroPreviewCase(name: "Longest amounts", kebutuhan: 12_450_000, keinginan: 12_350_000),
        HeroPreviewCase(name: "Needs only", kebutuhan: 50_000, keinginan: 0),
        HeroPreviewCase(name: "Wants only", kebutuhan: 0, keinginan: 50_000),
        HeroPreviewCase(name: "50 / 50", kebutuhan: 50_000, keinginan: 50_000),
        HeroPreviewCase(name: "Both budgets set: no link", kebutuhan: 3_120_000, keinginan: 1_130_000, budgets: [.kebutuhan: 4_000_000, .keinginan: 1_500_000]),
    ])
}

#Preview("Empty") {
    HeroPreviewList(cases: [
        HeroPreviewCase(name: "Empty month", kebutuhan: 0, keinginan: 0),
        HeroPreviewCase(name: "Empty month, Keinginan budget: no bar", kebutuhan: 0, keinginan: 0, budgets: [.keinginan: 1_000_000]),
    ])
}
