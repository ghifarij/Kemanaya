import KemanayaCore
import SwiftUI

/// The top of a month in Riwayat (D-053, D-073): "November 2026", then two labelled figures side by side,
/// a caption above each amount: "Pengeluaran / Rp4.250.000" and, when the month has income, "Pemasukan /
/// Rp8.500.000". No plus sign: the caption says which is which. At large text the figures wrap under each
/// other instead of shrinking. Neutral numbers, never a verdict (D-022).
struct HistoryMonthHeader: View {
    let month: MonthKey
    let totals: HistoryTotals
    let timeZone: TimeZone

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title)
                .font(.brandTitle)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) { figures }
                VStack(alignment: .leading, spacing: 8) { figures }
            }
        }
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HistoryHeaderLabel.month(title: title, totals: totals))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("history.month")
    }

    /// Pengeluaran always (Rp0 for a month with only income), Pemasukan only when there is some.
    @ViewBuilder private var figures: some View {
        LabelledFigure(label: Text(TransactionKind.expense.captionTitle), amount: totals.expenses)
        if totals.hasIncome {
            LabelledFigure(label: Text(TransactionKind.income.captionTitle), amount: totals.income)
        }
    }

    private var title: String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }
}

/// A caption above an amount, e.g. "Pengeluaran" over "Rp4.250.000" (D-073).
private struct LabelledFigure: View {
    let label: Text
    let amount: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            label
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
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

/// What VoiceOver reads for a month header, matching what it shows (D-073): "November 2026, pengeluaran
/// 4250000 rupiah, pemasukan 8500000 rupiah", pemasukan only when there is some.
private enum HistoryHeaderLabel {
    static func month(title: String, totals: HistoryTotals) -> String {
        var parts = [
            title,
            String(
                localized: "pengeluaran \(totals.expenses) rupiah",
                comment: "VoiceOver: a Riwayat month header's spending, in whole rupiah."
            ),
        ]
        if totals.hasIncome {
            parts.append(String(
                localized: "pemasukan \(totals.income) rupiah",
                comment: "VoiceOver: a Riwayat month header's income, in whole rupiah."
            ))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    let zone = TimeZone.autoupdatingCurrent
    List {
        Section {
            Text(verbatim: "Month with income")
        } header: {
            HistoryMonthHeader(month: MonthKey(year: 2026, month: 11), totals: HistoryTotals(expenses: 4_250_000, income: 8_500_000), timeZone: zone)
        }
        Section {
            Text(verbatim: "Month without income")
        } header: {
            HistoryMonthHeader(month: MonthKey(year: 2026, month: 10), totals: HistoryTotals(expenses: 3_980_500), timeZone: zone)
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
