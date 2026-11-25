import KemanayaCore
import SwiftUI

/// The top of a month in Riwayat (D-053, D-073, D-074): "November 2026", then labelled figures, a caption
/// above each amount: "Pengeluaran / Rp4.250.000" on the left and, when the month has income,
/// "Pemasukan / Rp8.500.000" on the right, right-aligned, with a flexible gap between. No plus sign: the
/// caption says which is which. When they don't fit side by side (large text) they stack on the left
/// instead of shrinking. Neutral numbers, never a verdict (D-022).
///
/// Under Riwayat's filter, `kinds` holds the kinds the filter lets through (``HistoryFilter/allowedKinds``,
/// D-075: the ticked groups' kinds) and `totals` covers only the rows shown, so Kebutuhan alone shows only
/// Pengeluaran. Home's month list has no filter and keeps the default, every kind.
struct HistoryMonthHeader: View {
    let month: MonthKey
    let totals: HistoryTotals
    let timeZone: TimeZone
    var kinds: Set<TransactionKind> = Set(TransactionKind.allCases)

    @Environment(\.locale) private var locale

    var body: some View {
        let figures = totals.figures(allowing: kinds)
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title)
                .font(.brandTitle)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(figures.enumerated()), id: \.element) { index, kind in
                        if index > 0 { Spacer(minLength: 24) }
                        LabelledFigure(kind: kind, amount: totals.amount(of: kind), alignment: index > 0 ? .trailing : .leading)
                            .fixedSize()
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(figures, id: \.self) { kind in
                        LabelledFigure(kind: kind, amount: totals.amount(of: kind), alignment: .leading)
                    }
                }
            }
        }
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HistoryHeaderLabel.month(title: title, totals: totals, figures: figures))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("history.month")
    }

    private var title: String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }
}

/// A caption above an amount, e.g. "Pengeluaran" over "Rp4.250.000" (D-073), both on one edge.
private struct LabelledFigure: View {
    let kind: TransactionKind
    let amount: Int64
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(kind.captionTitle)
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
            AmountText(amount, size: .medium)
                .foregroundStyle(Color(.textPrimary))
        }
    }
}

/// A sticky day header in Riwayat and Home's month list (D-053, D-073): the date only, e.g. "Kamis, 19 Nov".
/// No day total: next to the month's "Pengeluaran" figure it read as a second, competing total.
struct HistoryDayHeader: View {
    let day: DayKey
    let timeZone: TimeZone

    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: title)
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Color(.textPrimary))
            .textCase(nil)
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.appBackground))
            .listRowInsets(EdgeInsets())
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("history.day")
    }

    private var title: String {
        day.start(in: timeZone).formatted(Date.FormatStyle.historyDay(locale: locale, timeZone: timeZone))
    }
}

/// What VoiceOver reads for a month header, matching what it shows (D-073, D-074): "November 2026,
/// pengeluaran 4250000 rupiah, pemasukan 8500000 rupiah", one part per figure shown.
private enum HistoryHeaderLabel {
    static func month(title: String, totals: HistoryTotals, figures: [TransactionKind]) -> String {
        let parts = figures.map { kind in
            switch kind {
            case .expense: String(
                localized: "pengeluaran \(totals.expenses) rupiah",
                comment: "VoiceOver: a Riwayat month header's spending, in whole rupiah."
            )
            case .income: String(
                localized: "pemasukan \(totals.income) rupiah",
                comment: "VoiceOver: a Riwayat month header's income, in whole rupiah."
            )
            }
        }
        return ([title] + parts).joined(separator: ", ")
    }
}

#Preview {
    let zone = TimeZone.autoupdatingCurrent
    List {
        Section {
            Text(verbatim: "Month with income: left and right")
        } header: {
            HistoryMonthHeader(month: MonthKey(year: 2026, month: 11), totals: HistoryTotals(expenses: 4_250_000, income: 8_500_000), timeZone: zone)
        }
        Section {
            Text(verbatim: "Longest amounts")
        } header: {
            HistoryMonthHeader(month: MonthKey(year: 2026, month: 9), totals: HistoryTotals(expenses: 124_500_000, income: 123_500_000), timeZone: zone)
        }
        Section {
            Text(verbatim: "Month without income")
        } header: {
            HistoryMonthHeader(month: MonthKey(year: 2026, month: 10), totals: HistoryTotals(expenses: 3_980_500), timeZone: zone)
        }
        Section {
            Text(verbatim: "Filtered: Keinginan (expenses only)")
        } header: {
            HistoryMonthHeader(month: MonthKey(year: 2026, month: 8), totals: HistoryTotals(expenses: 1_130_000), timeZone: zone, kinds: [.expense])
        }
        Section {
            Text(verbatim: "Filtered: Pemasukan only")
        } header: {
            HistoryMonthHeader(month: MonthKey(year: 2026, month: 7), totals: HistoryTotals(income: 8_500_000), timeZone: zone, kinds: [.income])
        }
        Section {
            Text(verbatim: "A day: the date only")
        } header: {
            HistoryDayHeader(day: DayKey(year: 2026, month: 11, day: 19), timeZone: zone)
        }
    }
    .listStyle(.plain)
    .foregroundStyle(Color(.textPrimary))
    .background(Color(.appBackground))
}
