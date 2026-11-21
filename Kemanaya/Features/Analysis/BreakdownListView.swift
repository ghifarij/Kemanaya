import KemanayaCore
import SwiftData
import SwiftUI

/// The month's full Rincian (D-070), pushed by **Lihat semua** under Analisis's top 5: the month, the
/// group filter (the same one as Analisis, so going back keeps it), the donut and every ranked
/// subcategory. Rows open the subcategory detail, as on Analisis.
///
/// It fetches its month itself, so it stays live while a detail it opened changes a transaction.
struct BreakdownListView: View {
    let month: MonthKey
    let timeZone: TimeZone
    @Binding var filter: ExpenseFilter

    @Environment(\.locale) private var locale
    @Query private var transactions: [MoneyTransaction]
    /// The month's rollups, as on Analisis (D-055): the oldest month can be caught mid-purge.
    @Query private var rollups: [MonthlyRollup]
    /// Every subcategory, hidden ones too: spending logged before hiding still shows (D-006).
    @Query private var subcategories: [Subcategory]

    init(month: MonthKey, timeZone: TimeZone, filter: Binding<ExpenseFilter>) {
        self.month = month
        self.timeZone = timeZone
        _filter = filter
        _transactions = Query(MoneyTransaction.descriptor(in: month.dateRange(in: timeZone)))
        _rollups = Query(MonthlyRollup.descriptor(from: month, through: month))
    }

    var body: some View {
        let summary = MonthTotals(
            transactions: transactions.map(TransactionSnapshot.init),
            rollups: rollups.compactMap(RollupSnapshot.init),
            timeZone: timeZone
        ).summary(for: month)
        let byID = Dictionary(subcategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: monthTitle)
                    .font(.headline)
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("breakdown.month")
                BreakdownSection(
                    breakdown: Breakdown(summary: summary, filter: filter),
                    monthHasSpending: summary.expenses > 0,
                    monthTitle: monthTitle,
                    filter: $filter,
                    subcategories: byID,
                    route: { SubcategoryDetailRoute(subcategory: $0, month: month, timeZone: timeZone) },
                    seeAll: nil,
                    showsHeader: false
                )
            }
            .padding(16)
        }
        .accessibilityIdentifier("breakdown.scroll")
        .foregroundStyle(Color(.textPrimary))
        .background(Color(.appBackground).ignoresSafeArea())
        .navigationTitle(Text(BreakdownSection.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "November 2026".
    private var monthTitle: String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }
}

#if DEBUG
#Preview {
    @Previewable @State var filter = ExpenseFilter.all
    NavigationStack {
        BreakdownListView(month: CurrentMonth.now.month, timeZone: .autoupdatingCurrent, filter: $filter)
    }
    .modelContainer(PreviewStore.makeContainer())
}
#endif
