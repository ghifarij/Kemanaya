import KemanayaCore
import SwiftData
import SwiftUI

/// Where a subcategory detail opens: from an Analisis ranked row (the selected month) or a pinned
/// card's **Lihat detail** (the current month) (D-051).
struct SubcategoryDetailRoute: Hashable {
    let subcategory: Subcategory
    let month: MonthKey
    /// The device zone the month was bucketed in, by identifier so the route stays `Hashable`.
    let timeZoneID: String

    init(subcategory: Subcategory, month: MonthKey, timeZone: TimeZone) {
        self.subcategory = subcategory
        self.month = month
        self.timeZoneID = timeZone.identifier
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .autoupdatingCurrent
    }
}

/// One subcategory's month (D-041, D-051, D-082): the budget first when one is set, then this month and
/// the month before as two tiles with one comparison line, then the month's transactions. Rows open by
/// swipe only, **Hapus** or **Ubah** (the add/edit sheet), as in Riwayat (D-079).
///
/// The comparison is a neutral fact, "Naik Rp35.000 dari Oktober", in the secondary colour: no praise for
/// spending less, no alarm for more (D-022).
struct SubcategoryDetailView: View {
    let route: SubcategoryDetailRoute

    @Environment(\.locale) private var locale
    @Query private var current: [MoneyTransaction]
    @Query private var previous: [MoneyTransaction]
    /// The month before's rollup: the oldest month of the stepper compares with a purged month (D-055).
    @Query private var previousRollups: [MonthlyRollup]
    @State private var editing: MoneyTransaction?
    @State private var pendingDelete: PendingTransactionDelete?

    init(route: SubcategoryDetailRoute) {
        self.route = route
        let id = route.subcategory.id
        _current = Query(MoneyTransaction.descriptor(in: route.month.dateRange(in: route.timeZone), filter: .subcategory(id)))
        _previous = Query(MoneyTransaction.descriptor(in: route.month.previous.dateRange(in: route.timeZone), filter: .subcategory(id)))
        _previousRollups = Query(FetchDescriptor(predicate: MonthlyRollup.predicate(in: route.month.previous, subcategoryID: id)))
    }

    private var subcategory: Subcategory { route.subcategory }

    var body: some View {
        let lastMonth = MonthTotals(
            transactions: previous.map(TransactionSnapshot.init),
            rollups: previousRollups.compactMap(RollupSnapshot.init),
            timeZone: route.timeZone
        ).summary(for: route.month.previous)
        let detail = SubcategoryDetail(
            subcategoryID: subcategory.id,
            current: current.map(TransactionSnapshot.init),
            previous: lastMonth,
            monthlyBudget: subcategory.monthlyBudget
        )
        List {
            SubcategoryDetailHeader(
                detail: detail,
                tint: CategoryTint(kind: subcategory.kind, group: subcategory.group),
                monthTitle: title(of: route.month),
                previousMonthTitle: title(of: route.month.previous),
                previousMonthName: comparisonName(of: route.month.previous)
            )
            if current.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(current) { transaction in
                        row(for: transaction)
                    }
                } header: {
                    Text("Transaksi", comment: "Subcategory detail: header above the month's transactions.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground).ignoresSafeArea())
        .foregroundStyle(Color(.textPrimary))
        .accessibilityIdentifier("detail.list")
        .navigationTitle(Text(verbatim: "\(subcategory.emoji) \(subcategory.displayName)"))
        .navigationBarTitleDisplayMode(.inline)
        .transactionDeleteAlert($pendingDelete)
        .sheet(item: $editing) { transaction in
            AddTransactionSheet(mode: .edit(transaction))
        }
    }

    private func row(for transaction: MoneyTransaction) -> some View {
        // No tap: rows open by swipe only, Hapus or Ubah, which VoiceOver lists in the actions rotor (D-079).
        TransactionRow(transaction: transaction)
            .listRowBackground(Color(.surface))
            .accessibilityIdentifier("detail.row")
            .transactionSwipeActions {
                editing = transaction
            } onDelete: {
                pendingDelete = PendingTransactionDelete(transaction)
            }
    }

    /// Nothing logged in the subcategory this month: calm, never a verdict (D-022).
    private var emptyState: some View {
        Text(
            "Belum ada catatan di \(subcategory.displayName) pada \(title(of: route.month)).",
            comment: "Subcategory detail when the month has no transactions in it. 1: subcategory name, e.g. Kopi, 2: the month, e.g. November 2026."
        )
        .font(.subheadline)
        .foregroundStyle(Color(.textSecondary))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("detail.empty")
    }

    private func title(of month: MonthKey) -> String {
        month.start(in: route.timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: route.timeZone).month(.wide).year())
    }

    /// The month before as the comparison line names it (D-082): "Oktober" when it falls in the same year as
    /// the detail's month, so the line stays short; "Desember 2025" across a new year, where the month alone
    /// could read as the coming December.
    private func comparisonName(of month: MonthKey) -> String {
        guard month.year == route.month.year else { return title(of: month) }
        return month.start(in: route.timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: route.timeZone).month(.wide))
    }
}

/// The detail's numbers above the transactions (D-082), as list sections: the budget card first when a
/// budget is set, then this month and the month before as two tiles, then one comparison line.
///
/// The budget card is a plain `surface` row, like the transactions below, so only the bar carries the
/// group colour. The tiles sit straight on the screen background, each with its own surface: this month on
/// the subcategory's tinted card surface (the Home card colours, D-040), the month before on plain
/// `surface`. Every text pair is one `TokenContrastTests` already checks.
private struct SubcategoryDetailHeader: View {
    let detail: SubcategoryDetail
    let tint: CategoryTint
    let monthTitle: String
    let previousMonthTitle: String
    /// The month before as the comparison line names it: without its year when it's the same year.
    let previousMonthName: String

    var body: some View {
        if let budget = detail.budget {
            Section {
                SubcategoryBudgetCard(budget: budget, tint: tint)
                    .listRowBackground(Color(.surface))
            }
        }
        Section {
            VStack(alignment: .leading, spacing: 10) {
                MonthTiles(
                    current: MonthTile(
                        title: monthTitle,
                        total: detail.total,
                        count: detail.count,
                        background: tint.surface,
                        content: tint.content,
                        secondaryContent: tint.secondaryContent
                    )
                    .accessibilityIdentifier("detail.total"),
                    previous: MonthTile(
                        title: previousMonthTitle,
                        total: detail.previousTotal,
                        count: detail.previousCount,
                        background: .surface,
                        content: .textPrimary,
                        secondaryContent: .textSecondary
                    )
                    .accessibilityIdentifier("detail.previous")
                )
                comparisonText
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MonthTile.padding)
                    .accessibilityIdentifier("detail.comparison")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    /// "Naik Rp35.000 dari Oktober": the plain difference, nothing else; the tiles show both totals (D-082).
    private var comparisonText: Text {
        let amount = Int64(clamping: detail.difference.magnitude).rupiahFormatted
        return switch detail.comparison.direction {
        case .up: Text(
            "Naik \(amount) dari \(previousMonthName)",
            comment: "Subcategory detail, under the two month tiles: this month's total is higher than the month before (D-082). 1: the difference, e.g. Rp35.000, 2: the month before, e.g. Oktober (with its year, e.g. Desember 2025, when it's in another year). Neutral: state it, never praise or blame."
        )
        case .down: Text(
            "Turun \(amount) dari \(previousMonthName)",
            comment: "Subcategory detail, under the two month tiles: this month's total is lower than the month before (D-082). 1: the difference, e.g. Rp35.000, 2: the month before, e.g. Oktober (with its year, e.g. Desember 2025, when it's in another year). Neutral: state it, never praise or blame."
        )
        case .same: Text(
            "Sama dengan \(previousMonthName)",
            comment: "Subcategory detail, under the two month tiles: this month's total equals the month before's (D-082). The placeholder is the month before, e.g. Oktober (with its year, e.g. Desember 2025, when it's in another year)."
        )
        }
    }
}

/// The subcategory's budget, first in the detail (D-082): "Anggaran: sisa Rp250.000" (or "lewat …"), one
/// budget bar, and the standing budget under it. Neutral either way (D-022).
private struct SubcategoryBudgetCard: View {
    let budget: BudgetProgress
    let tint: CategoryTint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            budget.labelledStatusText
                .font(.headline.monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
            BudgetMeter(progress: budget, tint: tint, style: .bar)
            Text(
                "dari \(budget.budget.rupiahFormatted) per bulan",
                comment: "Subcategory detail, under the budget bar: the subcategory's standing monthly budget, e.g. 'dari Rp1.000.000 per bulan' (D-082). The placeholder is the full monthly budget."
            )
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Color(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .foregroundStyle(Color(.textPrimary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Anggaran", comment: "VoiceOver label of the budget block in the subcategory detail."))
        .accessibilityValue(Text(budget.accessibilityStatus))
        .accessibilityIdentifier("detail.budget")
    }
}

/// This month and the month before, side by side at equal widths while both fit whole; stacked, this month
/// first, when either amount would have to shrink, and always at the accessibility text sizes (D-082).
private struct MonthTiles<Current: View, Previous: View>: View {
    let current: Current
    let previous: Previous

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stacked
            } else {
                ViewThatFits(in: .horizontal) {
                    EqualWidthHStack(spacing: Self.spacing) {
                        current
                        previous
                    }
                    stacked
                }
            }
        }
        // The tiles take their own height; the row grows with them.
        .fixedSize(horizontal: false, vertical: true)
    }

    private static var spacing: CGFloat { 10 }

    private var stacked: some View {
        VStack(spacing: Self.spacing) {
            current
            previous
        }
    }
}

/// One month in the detail: its name, total and number of transactions, read by VoiceOver as one element,
/// e.g. "November 2026, 750000 rupiah, 12 transaksi".
private struct MonthTile: View {
    static let padding: CGFloat = 14

    let title: String
    let total: Int64
    let count: Int
    let background: ColorResource
    let content: ColorResource
    let secondaryContent: ColorResource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.subheadline)
                .foregroundStyle(Color(secondaryContent))
                .fixedSize(horizontal: false, vertical: true)
            AmountText(total, size: .medium)
                .foregroundStyle(Color(content))
            Text(
                "\(count) transaksi",
                comment: "Subcategory detail, in a month tile: the number of transactions in that month, e.g. '3 transaksi' (D-082)."
            )
            .font(.subheadline)
            .foregroundStyle(Color(secondaryContent))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Self.padding)
        .background(Color(background), in: .rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Lays its views out in a row at one shared width, the widest one's, and one shared height. Its ideal
/// width is that width times the count, so a `ViewThatFits` only picks it when every view fits whole.
private struct EqualWidthHStack: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let width = proposal.width.map { max(($0 - gaps) / CGFloat(subviews.count), 0) } ?? idealWidth(of: subviews)
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 0
        return CGSize(width: width * CGFloat(subviews.count) + gaps, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let width = max((bounds.width - gaps) / CGFloat(subviews.count), 0)
        var x = bounds.minX
        for subview in subviews {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func idealWidth(of subviews: Subviews) -> CGFloat {
        subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
    }
}

#if DEBUG
/// A detail on an in-memory store: Kopi with `budget`, this month's and the month before's amounts.
@MainActor
private func detailPreview(budget: Int64?, current: [Int64], previous: [Int64]) -> some View {
    let container = PreviewStore.makeContainer(withSamples: false)
    let context = container.mainContext
    let zone = TimeZone.autoupdatingCurrent
    let month = CurrentMonth.now.month
    let ledger = Ledger(context: context, timeZone: zone)
    let kopi = try? context.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == "Kopi" })).first
    if let kopi {
        try? ledger.setMonthlyBudget(budget, for: kopi)
        for (index, amount) in current.enumerated() {
            _ = try? ledger.addTransaction(amount: amount, subcategory: kopi, date: .now.addingTimeInterval(-Double(index) * 3_600), note: nil)
        }
        let lastMonth = month.previous.start(in: zone)
        for (index, amount) in previous.enumerated() {
            _ = try? ledger.addTransaction(amount: amount, subcategory: kopi, date: lastMonth.addingTimeInterval(Double(index + 1) * 86_400), note: nil)
        }
    }
    return NavigationStack {
        if let kopi {
            SubcategoryDetailView(route: SubcategoryDetailRoute(subcategory: kopi, month: month, timeZone: zone))
        }
    }
    .modelContainer(container)
}

#Preview("Under budget") {
    detailPreview(budget: 300_000, current: [18_000, 25_000, 22_000], previous: [40_000, 40_000])
}

#Preview("Over budget") {
    detailPreview(budget: 300_000, current: [180_000, 120_000, 36_500], previous: [250_000, 51_000])
}

#Preview("No budget") {
    detailPreview(budget: nil, current: [1_250_000, 18_000], previous: [1_250_000, 18_000])
}

#Preview("Month before empty") {
    detailPreview(budget: 300_000, current: [18_000], previous: [])
}

#Preview("Empty month") {
    detailPreview(budget: nil, current: [], previous: [45_000])
}
#endif
