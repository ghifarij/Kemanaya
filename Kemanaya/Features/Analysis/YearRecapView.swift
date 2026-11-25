import KemanayaCore
import SwiftData
import SwiftUI

/// Pushed by the **Rekap tahunan** row at the end of Analisis (D-059).
struct YearRecapRoute: Hashable {}

/// The **Rekap tahunan** row at the end of the Analisis page (D-059): opens the yearly recap.
struct YearRecapLink: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationLink(value: YearRecapRoute()) {
            HStack(spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(Color(.brand))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(YearRecapView.title)
                        .font(.headline)
                    Text(
                        "Pengeluaran dan pemasukan per tahun",
                        comment: "Analisis: the line under the Rekap tahunan row, which opens the yearly recap of spending and income."
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("analysis.recap")
    }
}

/// The yearly recap (D-014, D-017, D-059): a year stepper ("‹ 2026 ›") from the earliest year with data
/// to this year, which reads "Sampai hari ini" (year to date); the year's pengeluaran and pemasukan, the
/// Kebutuhan / Keinginan split, twelve months of pengeluaran and pemasukan, and the ranked expense
/// subcategories. Purged months come from their rollups, so a completed year stays whole.
///
/// Neutral numbers only (D-022): nothing praises or warns about a year.
struct YearRecapView: View {
    static let title = LocalizedStringResource(
        "Rekap tahunan",
        comment: "Title of the yearly recap screen and of the Analisis row that opens it: a year's spending and income."
    )

    @State private var current = CurrentMonth.now
    /// The year on screen; nil follows the current year (also into a new year).
    @State private var selected: Int?
    @Query(MoneyTransaction.earliestDescriptor) private var earliestTransaction: [MoneyTransaction]
    @Query(MonthlyRollup.earliestDescriptor) private var earliestRollup: [MonthlyRollup]

    var body: some View {
        let range = YearRecapRange(earliestMonth: earliestMonth, current: current.month)
        YearRecapContent(
            year: range.clamped(selected ?? range.latest),
            current: current.month,
            timeZone: current.timeZone,
            range: range,
            selected: $selected
        )
        .trackingCurrentMonth($current)
        .navigationTitle(Text(Self.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The oldest month with a transaction or a rollup, as ``Ledger/earliestMonthWithData()`` finds it.
    private var earliestMonth: MonthKey? {
        let transaction = earliestTransaction.first.map { MonthKey(containing: $0.date, timeZone: current.timeZone) }
        return [transaction, earliestRollup.first?.month].compactMap(\.self).min()
    }
}

/// The recap of one year. `@Query` keeps it live; a new year, time zone or selection re-runs `init`.
private struct YearRecapContent: View {
    let year: Int
    let current: MonthKey
    let timeZone: TimeZone
    let range: YearRecapRange
    @Binding var selected: Int?

    @Query private var transactions: [MoneyTransaction]
    @Query private var rollups: [MonthlyRollup]
    /// Every subcategory, hidden ones too, for their current names (D-006).
    @Query private var subcategories: [Subcategory]

    init(year: Int, current: MonthKey, timeZone: TimeZone, range: YearRecapRange, selected: Binding<Int?>) {
        self.year = year
        self.current = current
        self.timeZone = timeZone
        self.range = range
        _selected = selected
        _transactions = Query(MoneyTransaction.descriptor(in: YearRecap.dateRange(of: year, timeZone: timeZone)))
        _rollups = Query(MonthlyRollup.descriptor(from: MonthKey(year: year, month: 1), through: MonthKey(year: year, month: 12)))
    }

    var body: some View {
        let labels = subcategories.reduce(into: [UUID: SubcategoryLabel]()) { result, subcategory in
            result[subcategory.id] = SubcategoryLabel(name: subcategory.name, emoji: subcategory.emoji)
        }
        let recap = YearRecap(
            year: year,
            transactions: transactions.map(TransactionSnapshot.init),
            rollups: rollups.compactMap(RollupSnapshot.init),
            current: current,
            subcategories: labels,
            timeZone: timeZone
        )
        // "2026", never "2.026": a year is not a number with separators.
        let yearText = String(year)
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                YearStepper(year: yearBinding, range: range, isYearToDate: recap.isYearToDate)
                if recap.isEmpty {
                    AnalysisEmptyNote(
                        title: Text(
                            "Belum ada catatan di \(yearText)",
                            comment: "Yearly recap when the year has no expense or income. The placeholder is the year, e.g. '2026'."
                        ),
                        message: Text(
                            "Pengeluaran dan pemasukan setahun akan dirangkum di sini.",
                            comment: "Yearly recap empty state description: a year's spending and income will be summed up here."
                        ),
                        identifier: "recap.empty"
                    )
                } else {
                    YearTotalsCard(recap: recap)
                    VStack(alignment: .leading, spacing: 16) {
                        AnalysisSectionHeader(title: Text("Per bulan", comment: "Yearly recap: header above the chart of spending and income per month."))
                        MonthlyFlowChart(
                            months: recap.months,
                            highlighted: nil,
                            timeZone: timeZone,
                            accessibilityTitle: Text(
                                "Pengeluaran dan pemasukan per bulan, \(yearText)",
                                comment: "VoiceOver label of the yearly recap's chart of spending and income per month. The placeholder is the year, e.g. '2026'."
                            ),
                            identifier: "recap.chart",
                            accessibilityAxisStride: 3
                        )
                    }
                    YearRanking(recap: recap, yearText: yearText)
                }
            }
            .padding(16)
        }
        .accessibilityIdentifier("recap.scroll")
        .foregroundStyle(Color(.textPrimary))
        .background(Color(.appBackground).ignoresSafeArea())
    }

    /// The stepper reads the clamped year on screen; picking this year goes back to following it.
    private var yearBinding: Binding<Int> {
        Binding(get: { year }, set: { selected = $0 == range.latest ? nil : $0 })
    }
}

/// The year's pengeluaran and pemasukan, and how the spending splits into Kebutuhan and Keinginan.
private struct YearTotalsCard: View {
    let recap: YearRecap

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                caption(Text(TransactionKind.expense.captionTitle))
                AmountText(recap.expenses, size: .large)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("recap.expenses")
            VStack(alignment: .leading, spacing: 2) {
                caption(Text(TransactionKind.income.captionTitle))
                AmountText(recap.income, size: .medium)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("recap.income")
            if recap.expenses > 0 {
                SplitBar(kebutuhan: recap.summary.kebutuhan, keinginan: recap.summary.keinginan)
                    .accessibilityIdentifier("recap.split")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    private func caption(_ text: Text) -> some View {
        text
            .font(.subheadline)
            .foregroundStyle(Color(.textSecondary))
    }
}

/// The year's expense subcategories, largest first, as Rincian's rows without budgets or links.
private struct YearRanking: View {
    let recap: YearRecap
    /// "2026".
    let yearText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AnalysisSectionHeader(title: Text(
                "Pengeluaran per kategori",
                comment: "Yearly recap: header above the expense subcategories ranked by their total for the year."
            ))
            if recap.ranking.isEmpty {
                AnalysisEmptyNote(
                    title: Text(
                        "Belum ada pengeluaran di \(yearText)",
                        comment: "Yearly recap when the year has income but no expenses. The placeholder is the year, e.g. '2026'."
                    ),
                    message: nil,
                    identifier: "recap.ranking.empty"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recap.ranking.slices.enumerated()), id: \.element.id) { index, slice in
                        if index > 0 {
                            Divider().padding(.leading, 16)
                        }
                        let label = label(for: slice.subcategoryID)
                        // The current name, or a deleted one's snapshot name (D-066), in the app language
                        // while it is still a seed name (D-076).
                        let name = SubcategoryNames.shown(id: slice.subcategoryID, storedName: label.name)
                        RankedRow(slice: slice, emoji: label.emoji, name: name, budget: nil, isLink: false)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: name))
                            .accessibilityValue(Text(BreakdownSection.accessibilityValue(slice, budget: nil)))
                            .accessibilityIdentifier("recap.row.\(label.name)")
                    }
                }
                .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
            }
        }
    }

    /// The current name, else the rollup's snapshot (``YearRecap/labels``), else "Tanpa kategori" (D-006).
    private func label(for id: UUID) -> SubcategoryLabel {
        recap.labels[id] ?? SubcategoryLabel(
            name: String(localized: "Tanpa kategori", comment: "Name shown for a transaction whose subcategory no longer exists."),
            emoji: "❔"
        )
    }
}

/// "‹ 2026 ›": picks the recap's year, from the earliest year with data to this year (D-059). This year
/// reads "Sampai hari ini" under it. Like ``MonthStepper``, VoiceOver reads one adjustable element.
private struct YearStepper: View {
    @Binding var year: Int
    let range: YearRecapRange
    let isYearToDate: Bool

    /// Grows with the text but is capped, so the year keeps the width at accessibility sizes.
    @ScaledMetric(relativeTo: .headline) private var scaledArrowSize: CGFloat = 44

    var body: some View {
        let yearText = String(year)
        HStack(spacing: 4) {
            arrow(systemImage: "chevron.left", target: range.year(before: year))
            VStack(spacing: 0) {
                Text(verbatim: yearText)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if isYearToDate {
                    Text("Sampai hari ini", comment: "Yearly recap: under the current year in the year stepper. The year so far, up to today.")
                        .font(.caption)
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityIdentifier("recap.ytd")
                }
            }
            .frame(maxWidth: .infinity)
            arrow(systemImage: "chevron.right", target: range.year(after: year))
        }
        .padding(4)
        .background(Color(.surface), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Tahun", comment: "VoiceOver label of the yearly recap's year stepper; its value is the year shown, e.g. 2026."))
        .accessibilityValue(isYearToDate
            ? Text("\(yearText), sampai hari ini", comment: "VoiceOver value of the year stepper on the current year, e.g. '2026, sampai hari ini' (the year so far).")
            : Text(verbatim: yearText))
        .accessibilityHint(Text(
            "Geser ke atas atau ke bawah untuk mengganti tahun.",
            comment: "VoiceOver hint of the yearly recap's year stepper: swipe up or down to change the year."
        ))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(to: range.year(after: year))
            case .decrement: step(to: range.year(before: year))
            @unknown default: break
            }
        }
        .accessibilityIdentifier("recap.year")
    }

    private var arrowSize: CGFloat { min(scaledArrowSize, 60) }

    private func arrow(systemImage: String, target: Int?) -> some View {
        Button {
            step(to: target)
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: arrowSize, height: arrowSize)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(target == nil ? .textSecondary : .brand))
        .disabled(target == nil)
        .opacity(target == nil ? 0.4 : 1)
    }

    private func step(to target: Int?) {
        guard let target else { return }
        year = target
    }
}

#if DEBUG
#Preview("With data") {
    NavigationStack {
        YearRecapView()
    }
    .modelContainer(PreviewStore.makeContainer())
}

#Preview("Empty") {
    NavigationStack {
        YearRecapView()
    }
    .modelContainer(PreviewStore.makeContainer(withSamples: false))
}
#endif
