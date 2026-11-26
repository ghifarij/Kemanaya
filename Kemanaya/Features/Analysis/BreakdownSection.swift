import Charts
import KemanayaCore
import SwiftUI

/// Pushed by Rincian's **Lihat semua** row (D-070): the month's full breakdown.
struct BreakdownRoute: Hashable {
    let month: MonthKey
}

/// Rincian (D-014, D-051, D-070): the group filter, a donut of the month's expense subcategories, and the
/// ranked list. Each row shows the total, its share of the month, and, when a budget is set (D-041), a
/// labelled line with what is left of it or how far over it is (D-081); tapping it opens the subcategory
/// detail. Sectors and share bars use the group colours (D-040):
/// the donut shows how the month splits, the list names each part.
///
/// On the Analisis page the list stops at the top ``Breakdown/topLimit`` rows, followed by
/// **Lihat semua ›** when more are left; that pushes ``BreakdownListView``, which shows every row.
struct BreakdownSection: View {
    /// "Rincian": the section's header on Analisis and the title of the full breakdown screen.
    static let title = LocalizedStringResource(
        "Rincian",
        comment: "Analisis: header of the breakdown section (donut and ranked list of expense subcategories), and the title of the screen with the full list."
    )

    let breakdown: Breakdown
    /// The month has any expense at all, whatever the filter: otherwise the filter is pointless and hidden.
    let monthHasSpending: Bool
    /// "November 2026".
    let monthTitle: String
    @Binding var filter: ExpenseFilter
    let subcategories: [UUID: Subcategory]
    let route: (Subcategory) -> SubcategoryDetailRoute
    /// Where **Lihat semua** goes, and the list stops at ``Breakdown/topLimit`` rows; nil shows every
    /// row (the full breakdown screen itself).
    var seeAll: BreakdownRoute?
    /// False on the full breakdown screen, whose navigation title already says Rincian.
    var showsHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsHeader {
                AnalysisSectionHeader(title: Text(Self.title))
            }
            if monthHasSpending {
                ChoiceChips(options: Self.filterOptions, selection: $filter)
                if breakdown.isEmpty {
                    AnalysisEmptyNote(
                        title: AnalysisEmptyNote.filteredTitle(filter, monthTitle: monthTitle),
                        message: nil,
                        identifier: "analysis.breakdown.empty"
                    )
                } else {
                    if let largest = breakdown.largest {
                        largestLine(largest)
                    }
                    BreakdownDonut(breakdown: breakdown) { lookup($0).name }
                    rankedList
                }
            } else {
                AnalysisEmptyNote(
                    title: Text(
                        "Belum ada pengeluaran di \(monthTitle)",
                        comment: "Analisis empty state title when the month has no expenses. The placeholder is the month, e.g. 'November 2026'."
                    ),
                    message: Text(
                        "Pengeluaran yang kamu catat akan muncul di sini, dibagi per kategori.",
                        comment: "Analisis empty state description: logged expenses will show here, split by subcategory."
                    ),
                    identifier: "analysis.empty",
                    mascot: .calm
                )
            }
        }
    }

    static let filterOptions: [ChoiceChips<ExpenseFilter>.Option] = [
        .init(
            value: .all,
            title: Text("Semua", comment: "Analisis group filter: all expenses, Kebutuhan and Keinginan together."),
            identifier: "analysis.filter.all"
        ),
        .init(value: .kebutuhan, title: Text(ExpenseGroup.kebutuhan.title), identifier: "analysis.filter.kebutuhan"),
        .init(value: .keinginan, title: Text(ExpenseGroup.keinginan.title), identifier: "analysis.filter.keinginan"),
    ]

    /// "Paling banyak di 🍚 Makan": the friendly fact from D-022's voice, never a verdict.
    private func largestLine(_ slice: Breakdown.Slice) -> some View {
        let name = lookup(slice.subcategoryID)
        return Text(
            "Paling banyak di \(name.emoji) \(name.name)",
            comment: "Analisis: the subcategory with the most spending this month. 1: its emoji, 2: its name, e.g. 'Paling banyak di 🍚 Makan'. A neutral fact, never praise or blame."
        )
        .font(.subheadline)
        .foregroundStyle(Color(.textSecondary))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("analysis.largest")
    }

    /// The rows on screen: the top ones on Analisis (D-070), all of them on the full screen.
    private var shownSlices: ArraySlice<Breakdown.Slice> {
        seeAll == nil ? breakdown.slices[...] : breakdown.topSlices()
    }

    private var rankedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(shownSlices.enumerated()), id: \.element.id) { index, slice in
                if index > 0 {
                    Divider().padding(.leading, 16)
                }
                rankedRow(slice)
            }
            if let seeAll, breakdown.hasMore() {
                Divider().padding(.leading, 16)
                seeAllRow(seeAll)
            }
        }
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    /// "Lihat semua ›": the last row of the list, in the brand colour like a native "See All" (D-070).
    private func seeAllRow(_ destination: BreakdownRoute) -> some View {
        NavigationLink(value: destination) {
            HStack(spacing: 12) {
                Text("Lihat semua", comment: "Analisis: the last row under the top 5 ranked subcategories; opens the full breakdown of the month.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.brand))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(Text(
            "\(breakdown.slices.count) kategori",
            comment: "VoiceOver value of Analisis's Lihat semua row: how many subcategories the full breakdown lists, e.g. '8 kategori'."
        ))
        .accessibilityIdentifier("analysis.seeAll")
    }

    @ViewBuilder private func rankedRow(_ slice: Breakdown.Slice) -> some View {
        let name = lookup(slice.subcategoryID)
        let budget = subcategories[slice.subcategoryID]?.monthlyBudget.flatMap { BudgetProgress(spent: slice.total, budget: $0) }
        let content = RankedRow(slice: slice, emoji: name.emoji, name: name.name, budget: budget, isLink: name.subcategory != nil)
        if let subcategory = name.subcategory {
            NavigationLink(value: route(subcategory)) {
                content
            }
            .buttonStyle(.plain)
            // On the link itself, as on Home's cards: VoiceOver reads one button with this label and value.
            .accessibilityLabel(Text(verbatim: name.name))
            .accessibilityValue(Text(Self.accessibilityValue(slice, budget: budget)))
            .accessibilityHint(Text("Ketuk untuk melihat detail.", comment: "VoiceOver hint on an Analisis ranked row: opens the subcategory detail."))
            .accessibilityIdentifier("analysis.row.\(subcategory.name)")
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: name.name))
                .accessibilityValue(Text(Self.accessibilityValue(slice, budget: budget)))
        }
    }

    /// The name, emoji and model of a slice's subcategory; a deleted one reads "Tanpa kategori" (D-006).
    private func lookup(_ id: UUID) -> SliceName {
        guard let subcategory = subcategories[id] else {
            return SliceName(
                name: String(localized: "Tanpa kategori", comment: "Name shown for a transaction whose subcategory no longer exists."),
                emoji: "❔",
                subcategory: nil
            )
        }
        return SliceName(name: subcategory.displayName, emoji: subcategory.emoji, subcategory: subcategory)
    }

    /// "750000 rupiah, 75 persen dari pengeluaran, anggaran …".
    static func accessibilityValue(_ slice: Breakdown.Slice, budget: BudgetProgress?) -> String {
        let share = slice.isUnderOnePercent
            ? String(localized: "kurang dari 1 persen", comment: "VoiceOver: a share of spending under one percent, e.g. a small subcategory in the Analisis breakdown.")
            : String(localized: "\(slice.percent) persen", comment: "VoiceOver: a whole-number share of spending, e.g. '75 persen'.")
        let reading = String(
            localized: "\(slice.total) rupiah, \(share) dari pengeluaran",
            comment: "VoiceOver value of an Analisis ranked row or donut sector. 1: the subcategory's total in whole rupiah, 2: its share, e.g. '75 persen'."
        )
        guard let budget else { return reading }
        return String(
            localized: "analysis.row.accessibilityValue.withBudget",
            defaultValue: "\(reading), \(budget.accessibilityStatus)",
            comment: "VoiceOver value of an Analisis ranked row with a budget. 1: total and share, 2: the budget and what is left or over. Keep the order."
        )
    }
}

/// What a ranked row and its sector are called.
private struct SliceName {
    /// The shown name (D-076).
    let name: String
    let emoji: String
    /// Nil when the subcategory no longer exists: the row then opens nothing.
    let subcategory: Subcategory?
}

/// One ranked subcategory: emoji, name and total; a share bar with "37% dari total" (D-073); and, only
/// when the subcategory has a budget, a third line "Anggaran: sisa Rp250.000" or "Anggaran: lewat
/// Rp36.500" (D-081). No budget meter: the share bar is the row's only bar.
/// Also the yearly recap's rows (D-059), without a budget or a link.
struct RankedRow: View {
    let slice: Breakdown.Slice
    let emoji: String
    let name: String
    let budget: BudgetProgress?
    let isLink: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 8

    var body: some View {
        let tint = CategoryTint(kind: .expense, group: slice.group)
        let isLarge = dynamicTypeSize.isAccessibilitySize
        HStack(alignment: .top, spacing: 12) {
            if !isLarge {
                Text(verbatim: emoji)
                    .font(.title2)
            }
            VStack(alignment: .leading, spacing: 8) {
                let layout = isLarge
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                layout {
                    Text(verbatim: isLarge ? "\(emoji) \(name)" : name)
                        .font(.body.weight(.semibold))
                        .lineLimit(isLarge ? nil : 1)
                    if !isLarge {
                        Spacer(minLength: 8)
                    }
                    AmountText(slice.total, size: .small)
                        .layoutPriority(1)
                }
                HStack(spacing: 10) {
                    shareBar(tint: tint)
                    percentText
                }
                if let budget {
                    // One labelled line, no meter (D-081): it wraps at large text sizes rather than shrinking.
                    budget.labelledStatusText
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if isLink {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private func shareBar(tint: CategoryTint) -> some View {
        Capsule()
            .fill(Color(.textPrimary).opacity(0.1))
            .frame(height: barHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color(tint.chartMark))
                        // A non-empty share always shows at least a dot.
                        .frame(width: max(proxy.size.width * slice.share, barHeight))
                }
            }
    }

    /// "37% dari total" (D-073): the share says what it is a share of.
    private var percentText: some View {
        ShareCopy.ofTotal(percent: slice.percent, isUnderOnePercent: slice.isUnderOnePercent, locale: locale)
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(Color(.textSecondary))
        .lineLimit(1)
        .fixedSize()
    }
}

/// The donut (Swift Charts `SectorMark`): one sector per ranked subcategory in its group colour, with the
/// filtered total in the middle. VoiceOver reads each sector's name, total and share.
private struct BreakdownDonut: View {
    let breakdown: Breakdown
    let name: (UUID) -> String

    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 220

    var body: some View {
        let size = min(scaledSize, 280)
        Chart(breakdown.slices) { slice in
            SectorMark(
                angle: .value(Text("Jumlah", comment: "Chart axis name: an amount of money."), Double(slice.total)),
                innerRadius: .ratio(0.62),
                angularInset: breakdown.slices.count > 1 ? 1.5 : 0
            )
            .cornerRadius(4)
            .foregroundStyle(Color(CategoryTint(kind: .expense, group: slice.group).chartMark))
            .accessibilityLabel(Text(verbatim: name(slice.subcategoryID)))
            .accessibilityValue(Text(BreakdownSection.accessibilityValue(slice, budget: nil)))
        }
        .chartLegend(.hidden)
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let frame = geometry[plotFrame]
                    centre
                        .frame(width: frame.width * 0.5)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("analysis.donut")
    }

    /// The filtered total: what the whole ring adds up to.
    private var centre: some View {
        VStack(spacing: 2) {
            Group {
                switch breakdown.filter {
                case .all: Text(TransactionKind.expense.captionTitle)
                case .kebutuhan: Text(ExpenseGroup.kebutuhan.title)
                case .keinginan: Text(ExpenseGroup.keinginan.title)
                }
            }
            .font(.caption)
            .foregroundStyle(Color(.textSecondary))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            AmountText(breakdown.total, size: .medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("analysis.donut.total")
    }
}

#if DEBUG
/// The three kinds of row (D-081): a budget with some left, a budget gone over, and no budget.
#Preview("Ranked rows") {
    let ids = (makan: UUID(), jajan: UUID(), transport: UUID())
    let transactions = [
        TransactionSnapshot(amount: 1_250_000, kind: .expense, group: .kebutuhan, subcategoryID: ids.makan, date: .now),
        TransactionSnapshot(amount: 336_500, kind: .expense, group: .keinginan, subcategoryID: ids.jajan, date: .now),
        TransactionSnapshot(amount: 180_000, kind: .expense, group: .kebutuhan, subcategoryID: ids.transport, date: .now),
    ]
    let slices = Breakdown(transactions).slices
    let rows: [(name: String, emoji: String, budget: Int64?)] = [
        ("Makan", "🍚", 1_500_000),
        ("Jajan", "🧋", 300_000),
        ("Transportasi", "🛵", nil),
    ]
    ScrollView {
        VStack(spacing: 0) {
            ForEach(Array(zip(slices, rows).enumerated()), id: \.offset) { index, pair in
                if index > 0 {
                    Divider().padding(.leading, 16)
                }
                RankedRow(
                    slice: pair.0,
                    emoji: pair.1.emoji,
                    name: pair.1.name,
                    budget: pair.1.budget.flatMap { BudgetProgress(spent: pair.0.total, budget: $0) },
                    isLink: true
                )
            }
        }
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
        .padding()
    }
    .background(Color(.appBackground))
}
#endif
