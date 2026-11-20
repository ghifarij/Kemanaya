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
                MonthlyFlowChart(
                    months: series.months,
                    highlighted: series.selected,
                    timeZone: timeZone,
                    accessibilityTitle: Text(
                        "Pengeluaran dan pemasukan, 6 bulan terakhir",
                        comment: "VoiceOver label of the Analisis six-month chart of spending and income."
                    ),
                    identifier: "analysis.series.chart"
                )
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

/// Short rupiah labels on a value axis in the app language (D-065): "Rp1,5jt" in Indonesian, "Rp1.5M" in English.
@AxisContentBuilder
private func rupiahAxis(desiredCount: Int, font: Font, locale: Locale) -> some AxisContent {
    let style = RupiahFormatter.CompactStyle(languageCode: locale.language.languageCode?.identifier)
    AxisMarks(position: .leading, values: .automatic(desiredCount: desiredCount)) { value in
        AxisGridLine()
        AxisValueLabel {
            if let amount = value.as(Double.self) {
                Text(verbatim: RupiahFormatter.compact(Int64(amount.rounded()), style: style))
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

    @Environment(\.locale) private var locale
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
            .chartYAxis { rupiahAxis(desiredCount: dynamicTypeSize.isAccessibilitySize ? 2 : 4, font: axisFont.font, locale: locale) }
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

// MARK: - (b) Months of pengeluaran and pemasukan

/// Pengeluaran and pemasukan side by side per month: Tren's six months (with the selected month
/// highlighted) and the yearly recap's twelve (D-059).
struct MonthlyFlowChart: View {
    let months: [MonthlyFlow]
    /// The month with a faint band and a bold axis label; nil highlights none.
    let highlighted: MonthKey?
    let timeZone: TimeZone
    /// What VoiceOver calls the chart, e.g. "Pengeluaran dan pemasukan, 6 bulan terakhir".
    let accessibilityTitle: Text
    let identifier: String
    /// At accessibility sizes only every `n`-th month is labelled on the axis (all at other sizes), so
    /// twelve labels don't collide. VoiceOver still reads every month.
    var accessibilityAxisStride = 1

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var scaledHeight: CGFloat = 200
    private let axisFont = AxisFont()

    /// A light neutral that differs from `pemasukanChart` in lightness as well as hue (D-055).
    private var expenseColor: Color { Color(.chartNeutral) }
    private var incomeColor: Color { Color(CategoryTint.pemasukan.chartMark) }

    var body: some View {
        let expenseName = String(localized: TransactionKind.expense.captionTitle)
        let incomeName = String(localized: TransactionKind.income.captionTitle)
        let highlightedLabel = highlighted.map(shortLabel)
        let labels = months.map { shortLabel($0.month) }
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                // The highlighted month's band, behind its bars. Kept faint (8 %) so the chartNeutral bar
                // still holds 3:1 against it in every appearance (D-040); the bold axis label marks it too.
                if let highlightedLabel {
                    RectangleMark(x: .value(Text("Bulan", comment: "Chart axis name: the month."), highlightedLabel))
                        .foregroundStyle(Color(.textSecondary).opacity(0.08))
                        .accessibilityHidden(true)
                }
                ForEach(months) { flow in
                    bar(flow, amount: flow.expenses, kind: expenseName, color: expenseColor)
                    bar(flow, amount: flow.income, kind: incomeName, color: incomeColor)
                }
            }
            .chartXScale(domain: labels)
            .chartXAxis {
                AxisMarks(values: axisLabels(labels)) { value in
                    AxisValueLabel(collisionResolution: .greedy) {
                        if let label = value.as(String.self) {
                            Text(verbatim: label)
                                .font(axisFont.font)
                                .fontWeight(label == highlightedLabel ? .bold : .regular)
                                .foregroundStyle(Color(label == highlightedLabel ? .textPrimary : .textSecondary))
                        }
                    }
                }
            }
            .chartYAxis { rupiahAxis(desiredCount: dynamicTypeSize.isAccessibilitySize ? 2 : 4, font: axisFont.font, locale: locale) }
            .chartLegend(.hidden)
            .frame(height: min(scaledHeight, maximumChartHeight))
            // Swift Charts would merge each month's pair into one element read as their average, so
            // VoiceOver gets one element per month that names both amounts instead.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityTitle)
            .accessibilityChildren {
                // Side by side, so each month's element sits over its own column, not the whole chart.
                HStack(spacing: 0) {
                    ForEach(months) { flow in
                        Rectangle()
                            .accessibilityLabel(Text(verbatim: longLabel(flow.month)))
                            .accessibilityValue(Text(
                                "pengeluaran \(flow.expenses) rupiah, pemasukan \(flow.income) rupiah",
                                comment: "VoiceOver value of one month in a chart of spending and income (Analisis six months, yearly recap). 1: spending, 2: income, both in whole rupiah."
                            ))
                    }
                }
            }
            .accessibilityIdentifier(identifier)
            ChartLegend(items: [
                (Text(TransactionKind.expense.captionTitle), expenseColor),
                (Text(TransactionKind.income.captionTitle), incomeColor),
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

    /// Every label, or every `accessibilityAxisStride`-th one (from the first) at accessibility sizes.
    private func axisLabels(_ labels: [String]) -> [String] {
        guard dynamicTypeSize.isAccessibilitySize, accessibilityAxisStride > 1 else { return labels }
        return labels.enumerated().filter { $0.offset.isMultiple(of: accessibilityAxisStride) }.map(\.element)
    }

    /// "Nov": unique within twelve consecutive months.
    private func shortLabel(_ month: MonthKey) -> String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.abbreviated))
    }

    /// "November 2026", for VoiceOver.
    private func longLabel(_ month: MonthKey) -> String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }
}
