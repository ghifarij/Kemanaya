import Charts
import KemanayaCore
import SwiftUI

/// Tren (D-014, D-051): (a) the month's spending per day or week, Kebutuhan and Keinginan stacked in
/// their group colours and following the group filter; (b) pengeluaran and pemasukan side by side for
/// the six months ending at the selected one, which is highlighted.
///
/// Neutral throughout (D-022): no colour or line marks a month as good or bad. Pengeluaran is a light
/// neutral grey and pemasukan its own colour, so neither reads as an alarm or a reward (D-055).
struct TrendSection: View {
    let trend: SpendingTrend
    let series: MonthlyFlowSeries
    let monthHasSpending: Bool
    /// "November 2026".
    let monthTitle: String
    let timeZone: TimeZone
    @Binding var granularity: TrendGranularity

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AnalysisSectionHeader(title: Text("Tren", comment: "Analisis: header of the trend section (spending per day or week, then six months)."))
            if monthHasSpending {
                ChoiceChips(options: Self.granularityOptions, selection: $granularity)
                if trend.isEmpty {
                    AnalysisEmptyNote(
                        title: AnalysisEmptyNote.filteredTitle(trend.filter, monthTitle: monthTitle),
                        message: nil,
                        identifier: "analysis.trend.empty"
                    )
                } else {
                    SpendingTrendChart(trend: trend)
                }
            }
            subheader(Text("6 bulan terakhir", comment: "Analisis: label above the chart of spending and income for the six months up to the selected month."))
            if series.isEmpty {
                AnalysisEmptyNote(
                    title: Text(
                        "Belum ada catatan dalam 6 bulan ini",
                        comment: "Analisis six-month chart: no expense or income in any of the six months."
                    ),
                    message: nil,
                    identifier: "analysis.series.empty"
                )
            } else {
                MonthlyFlowChart(series: series, timeZone: timeZone)
            }
        }
    }

    static let granularityOptions: [ChoiceChips<TrendGranularity>.Option] = [
        .init(
            value: .daily,
            title: Text("Harian", comment: "Analisis trend switch: spending per day of the month."),
            identifier: "analysis.granularity.daily"
        ),
        .init(
            value: .weekly,
            title: Text("Mingguan", comment: "Analisis trend switch: spending per week (Monday to Sunday) of the month."),
            identifier: "analysis.granularity.weekly"
        ),
    ]

    private func subheader(_ text: Text) -> some View {
        text
            .font(.headline)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Shared chart pieces

/// Chart heights grow with Dynamic Type but stay on screen at AX5.
private let maximumChartHeight: CGFloat = 340

/// A legend row: a dot in the mark's colour and its name. Wraps to a column when the row doesn't fit.
private struct ChartLegend: View {
    let items: [(title: Text, color: Color)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { entries }
            VStack(alignment: .leading, spacing: 6) { entries }
        }
        .font(.subheadline)
        .accessibilityHidden(true)
    }

    private var entries: some View {
        ForEach(items.indices, id: \.self) { index in
            HStack(spacing: 6) {
                Circle().fill(items[index].color).frame(width: 10, height: 10)
                items[index].title
                    .foregroundStyle(Color(.textSecondary))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// Short rupiah labels on a value axis ("Rp1,5jt").
@AxisContentBuilder
private func rupiahAxis(desiredCount: Int, font: Font) -> some AxisContent {
    AxisMarks(position: .leading, values: .automatic(desiredCount: desiredCount)) { value in
        AxisGridLine()
        AxisValueLabel {
            if let amount = value.as(Double.self) {
                Text(verbatim: RupiahFormatter.compact(Int64(amount.rounded())))
                    .font(font)
            }
        }
    }
}

/// Axis labels grow with Dynamic Type up to 18 pt: past that, AX5 labels collide and most are dropped.
/// The bars' VoiceOver labels and the ranked list carry the same facts at full size.
private struct AxisFont: DynamicProperty {
    @ScaledMetric(relativeTo: .caption2) private var size: CGFloat = 11

    var font: Font { .system(size: min(size, 18)) }
}

// MARK: - (a) Spending per day or week

private struct SpendingTrendChart: View {
    let trend: SpendingTrend

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledHeight: CGFloat = 200
    private let axisFont = AxisFont()

    var body: some View {
        let labels = trend.buckets.map(label)
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(trend.buckets) { bucket in
                    ForEach(trend.filter.groups, id: \.self) { group in
                        let amount = bucket.amount(for: group)
                        // Empty days draw nothing, so VoiceOver only visits days with spending.
                        if amount > 0 {
                            BarMark(
                                x: .value(Text("Tanggal", comment: "Chart axis name: the day or days of the month."), label(bucket)),
                                y: .value(Text("Jumlah", comment: "Chart axis name: an amount of money."), Double(amount))
                            )
                            .foregroundStyle(Color(CategoryTint(kind: .expense, group: group).chartMark))
                            .accessibilityLabel(Text(accessibilityLabel(bucket, group: group)))
                            .accessibilityValue(Text("\(amount) rupiah", comment: "VoiceOver reading of a money amount. The number is whole rupiah, without separators."))
                        }
                    }
                }
            }
            .chartXScale(domain: labels)
            .chartXAxis {
                AxisMarks(values: axisLabels(labels)) { value in
                    AxisValueLabel(collisionResolution: .greedy) {
                        if let label = value.as(String.self) {
                            Text(verbatim: label).font(axisFont.font)
                        }
                    }
                }
            }
            .chartYAxis { rupiahAxis(desiredCount: dynamicTypeSize.isAccessibilitySize ? 2 : 4, font: axisFont.font) }
            .chartLegend(.hidden)
            .frame(height: min(scaledHeight, maximumChartHeight))
            .accessibilityIdentifier("analysis.trend.chart")
            ChartLegend(items: trend.filter.groups.map { group in
                (Text(group.title), Color(CategoryTint(kind: .expense, group: group).chartMark))
            })
        }
        .padding(16)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    /// "12" for a day, "2–8" for a week (days of the month).
    private func label(_ bucket: SpendingBucket) -> String {
        bucket.firstDay == bucket.lastDay ? "\(bucket.firstDay)" : "\(bucket.firstDay)–\(bucket.lastDay)"
    }

    /// Every week; for days, the 1st and every 5th, fewer at accessibility sizes.
    private func axisLabels(_ labels: [String]) -> [String] {
        guard trend.granularity == .daily else { return labels }
        let step = dynamicTypeSize.isAccessibilitySize ? 10 : 5
        return trend.buckets.filter { $0.firstDay == 1 || $0.firstDay.isMultiple(of: step) }.map(label)
    }

    private func accessibilityLabel(_ bucket: SpendingBucket, group: ExpenseGroup) -> String {
        let groupName = String(localized: group.title)
        if bucket.firstDay == bucket.lastDay {
            return String(
                localized: "Tanggal \(bucket.firstDay), \(groupName)",
                comment: "VoiceOver label of a daily bar in the Analisis trend chart. 1: day of the month, 2: Kebutuhan or Keinginan."
            )
        }
        return String(
            localized: "Tanggal \(bucket.firstDay) sampai \(bucket.lastDay), \(groupName)",
            comment: "VoiceOver label of a weekly bar in the Analisis trend chart. 1: first day, 2: last day of the week in the month, 3: Kebutuhan or Keinginan."
        )
    }
}

// MARK: - (b) Six months of pengeluaran and pemasukan

private struct MonthlyFlowChart: View {
    let series: MonthlyFlowSeries
    let timeZone: TimeZone

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledHeight: CGFloat = 200
    private let axisFont = AxisFont()

    /// A light neutral that differs from `pemasukanChart` in lightness as well as hue (D-055).
    private var expenseColor: Color { Color(.chartNeutral) }
    private var incomeColor: Color { Color(CategoryTint.pemasukan.chartMark) }

    var body: some View {
        let expenseName = String(localized: TransactionKind.expense.title)
        let incomeName = String(localized: TransactionKind.income.title)
        let selectedLabel = shortLabel(series.selected)
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                // The selected month's band, behind its bars. Kept faint (8 %) so the chartNeutral bar
                // still holds 3:1 against it in every appearance (D-040); the bold axis label marks it too.
                RectangleMark(x: .value(Text("Bulan", comment: "Chart axis name: the month."), selectedLabel))
                    .foregroundStyle(Color(.textSecondary).opacity(0.08))
                    .accessibilityHidden(true)
                ForEach(series.months) { flow in
                    bar(flow, amount: flow.expenses, kind: expenseName, color: expenseColor)
                    bar(flow, amount: flow.income, kind: incomeName, color: incomeColor)
                }
            }
            .chartXScale(domain: series.months.map { shortLabel($0.month) })
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(collisionResolution: .greedy) {
                        if let label = value.as(String.self) {
                            Text(verbatim: label)
                                .font(axisFont.font)
                                .fontWeight(label == selectedLabel ? .bold : .regular)
                                .foregroundStyle(Color(label == selectedLabel ? .textPrimary : .textSecondary))
                        }
                    }
                }
            }
            .chartYAxis { rupiahAxis(desiredCount: dynamicTypeSize.isAccessibilitySize ? 2 : 4, font: axisFont.font) }
            .chartLegend(.hidden)
            .frame(height: min(scaledHeight, maximumChartHeight))
            // Swift Charts would merge each month's pair into one element read as their average, so
            // VoiceOver gets one element per month that names both amounts instead.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(
                "Pengeluaran dan pemasukan, 6 bulan terakhir",
                comment: "VoiceOver label of the Analisis six-month chart of spending and income."
            ))
            .accessibilityChildren {
                // Side by side, so each month's element sits over its own column, not the whole chart.
                HStack(spacing: 0) {
                    ForEach(series.months) { flow in
                        Rectangle()
                            .accessibilityLabel(Text(verbatim: longLabel(flow.month)))
                            .accessibilityValue(Text(
                                "pengeluaran \(flow.expenses) rupiah, pemasukan \(flow.income) rupiah",
                                comment: "VoiceOver value of one month in the Analisis six-month chart. 1: spending, 2: income, both in whole rupiah."
                            ))
                    }
                }
            }
            .accessibilityIdentifier("analysis.series.chart")
            ChartLegend(items: [
                (Text(TransactionKind.expense.title), expenseColor),
                (Text(TransactionKind.income.title), incomeColor),
            ])
        }
        .padding(16)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    private func bar(_ flow: MonthlyFlow, amount: Int64, kind: String, color: Color) -> some ChartContent {
        BarMark(
            x: .value(Text("Bulan", comment: "Chart axis name: the month."), shortLabel(flow.month)),
            y: .value(Text("Jumlah", comment: "Chart axis name: an amount of money."), Double(amount))
        )
        .position(by: .value(Text("Jenis", comment: "Chart series name: pengeluaran or pemasukan."), kind))
        .foregroundStyle(color)
    }

    /// "Nov": unique across six consecutive months.
    private func shortLabel(_ month: MonthKey) -> String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.abbreviated))
    }

    /// "November 2026", for VoiceOver.
    private func longLabel(_ month: MonthKey) -> String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }
}
