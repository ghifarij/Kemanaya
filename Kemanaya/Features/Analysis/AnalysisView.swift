import KemanayaCore
import SwiftData
import SwiftUI

/// The Analisis tab (D-014, D-051): one scrolling page with the month stepper on top, then Rincian
/// (a donut and the ranked expense subcategories, filtered by group) and Tren (the month's spending per
/// day or week, then six months of pengeluaran and pemasukan). A ranked row opens the subcategory detail;
/// the **Rekap tahunan** row at the end opens the yearly recap (D-059).
struct AnalysisView: View {
    @State private var current = CurrentMonth.now
    /// The month on screen; starts on the current month and follows it into a new month (see
    /// ``AnalysisMonthRange/carrying(_:from:)``).
    @State private var selected = CurrentMonth.now.month
    @State private var filter = ExpenseFilter.all
    @State private var granularity = TrendGranularity.daily

    var body: some View {
        let range = AnalysisMonthRange(current: current.month)
        NavigationStack {
            AnalysisContent(
                month: range.clamped(selected),
                timeZone: current.timeZone,
                range: range,
                selected: $selected,
                filter: $filter,
                granularity: $granularity
            )
            .navigationDestination(for: SubcategoryDetailRoute.self) { route in
                SubcategoryDetailView(route: route)
            }
            .navigationDestination(for: YearRecapRoute.self) { _ in
                YearRecapView()
            }
        }
        .trackingCurrentMonth($current)
        .onChange(of: current) { old, new in
            selected = AnalysisMonthRange(current: new.month).carrying(selected, from: AnalysisMonthRange(current: old.month))
        }
    }
}

/// The page for one month. One `@Query` fetches the six months the month-over-month chart needs (D-018);
/// the month's own numbers are taken from the same rows. A new month, time zone or selection re-runs
/// `init`, which rebuilds the range.
private struct AnalysisContent: View {
    let month: MonthKey
    let timeZone: TimeZone
    let range: AnalysisMonthRange
    @Binding var selected: MonthKey
    @Binding var filter: ExpenseFilter
    @Binding var granularity: TrendGranularity

    @Environment(\.locale) private var locale
    @Query private var transactions: [MoneyTransaction]
    /// Rollups of the same six months: near the window's start the chart reaches purged months (D-055).
    @Query private var rollups: [MonthlyRollup]
    /// Every subcategory, hidden ones too: spending logged before hiding still shows (D-006).
    @Query private var subcategories: [Subcategory]

    init(
        month: MonthKey,
        timeZone: TimeZone,
        range: AnalysisMonthRange,
        selected: Binding<MonthKey>,
        filter: Binding<ExpenseFilter>,
        granularity: Binding<TrendGranularity>
    ) {
        self.month = month
        self.timeZone = timeZone
        self.range = range
        _selected = selected
        _filter = filter
        _granularity = granularity
        _transactions = Query(MoneyTransaction.descriptor(in: MonthlyFlowSeries.dateRange(ending: month, timeZone: timeZone)))
        let months = MonthlyFlowSeries.months(ending: month)
        _rollups = Query(MonthlyRollup.descriptor(from: months[0], through: month))
    }

    var body: some View {
        let snapshots = transactions.map(TransactionSnapshot.init)
        let monthRange = month.dateRange(in: timeZone)
        let monthSnapshots = snapshots.filter { monthRange.contains($0.date) }
        let summary = MonthSummary(monthSnapshots)
        let monthHasSpending = summary.expenses > 0
        let byID = Dictionary(subcategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let totals = MonthTotals(transactions: snapshots, rollups: rollups.compactMap(RollupSnapshot.init), timeZone: timeZone)
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                MonthStepper(month: monthBinding, range: range, timeZone: timeZone)
                BreakdownSection(
                    breakdown: Breakdown(summary: summary, filter: filter),
                    monthHasSpending: monthHasSpending,
                    monthTitle: monthTitle,
                    filter: $filter,
                    subcategories: byID,
                    route: { SubcategoryDetailRoute(subcategory: $0, month: month, timeZone: timeZone) }
                )
                TrendSection(
                    trend: SpendingTrend(monthSnapshots, month: month, timeZone: timeZone, granularity: granularity, filter: filter),
                    series: MonthlyFlowSeries(totals: totals, ending: month),
                    monthHasSpending: monthHasSpending,
                    monthTitle: monthTitle,
                    timeZone: timeZone,
                    granularity: $granularity
                )
                YearRecapLink()
            }
            .padding(16)
        }
        .accessibilityIdentifier("analysis.scroll")
        .foregroundStyle(Color(.textPrimary))
        .background(Color(.appBackground).ignoresSafeArea())
        // A native large title (D-021): it collapses into the bar on scroll, so the page never runs
        // under the status bar, and it names the detail's back button.
        .navigationTitle(Text("Analisis", comment: "Title of the Analisis tab and its tab bar item: spending breakdown and trends."))
        .navigationBarTitleDisplayMode(.large)
    }

    /// The stepper writes the selection; it always reads the clamped month on screen.
    private var monthBinding: Binding<MonthKey> {
        Binding(get: { month }, set: { selected = $0 })
    }

    /// "November 2026".
    private var monthTitle: String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }
}

/// A calm note in place of a chart or list with nothing to show (D-022: an empty month is neither good nor bad).
struct AnalysisEmptyNote: View {
    let title: Text
    let message: Text?
    let identifier: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        layout {
            Image(systemName: "chart.pie")
                .font(.title3)
                .foregroundStyle(Color(.textSecondary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let message {
                    message
                        .font(.subheadline)
                        .foregroundStyle(Color(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

extension AnalysisEmptyNote {
    /// "Belum ada pengeluaran Keinginan di November 2026": the month has spending, but none in the
    /// filtered group. Rincian and Tren share it so both notes name the group.
    static func filteredTitle(_ filter: ExpenseFilter, monthTitle: String) -> Text {
        switch filter {
        case .keinginan: Text(
            "Belum ada pengeluaran Keinginan di \(monthTitle)",
            comment: "Analisis, Keinginan filter on: the month has expenses, but none in Keinginan. The placeholder is the month, e.g. 'November 2026'."
        )
        // `.all` can't be empty when the month has spending; it shares Kebutuhan's line as a fallback.
        case .all, .kebutuhan: Text(
            "Belum ada pengeluaran Kebutuhan di \(monthTitle)",
            comment: "Analisis, Kebutuhan filter on: the month has expenses, but none in Kebutuhan. The placeholder is the month, e.g. 'November 2026'."
        )
        }
    }
}

/// A section title on the Analisis page, e.g. Rincian or Tren.
struct AnalysisSectionHeader: View {
    let title: Text

    var body: some View {
        title
            .font(.title3.weight(.bold))
            .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("With data") {
    AnalysisView()
        .modelContainer(PreviewStore.makeContainer())
}

#Preview("Empty") {
    AnalysisView()
        .modelContainer(PreviewStore.makeContainer(withSamples: false))
}
#endif
