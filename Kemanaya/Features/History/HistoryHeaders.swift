import KemanayaCore
import SwiftUI

/// The top of a month in Riwayat (D-053): "November 2026", the month's pengeluaran, and its income as a
/// separate "+Rp…" in the secondary colour. Neutral numbers, never a verdict (D-022).
struct HistoryMonthHeader: View {
    let month: MonthKey
    let totals: HistoryTotals
    let timeZone: TimeZone

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title)
                .font(.brandTitle)
                .fixedSize(horizontal: false, vertical: true)
            // Wraps to two lines instead of shrinking when both amounts don't fit (large text).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) { amounts }
                VStack(alignment: .leading, spacing: 2) { amounts }
            }
        }
        .padding(.top, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HistoryHeaderLabel.text(title: title, totals: totals))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("history.month")
    }

    @ViewBuilder private var amounts: some View {
        if totals.hasExpenses || !totals.hasIncome {
            AmountText(totals.expenses, size: .medium)
        }
        if totals.hasIncome {
            AmountText(totals.income, size: .small, showsPlusSign: true)
                .foregroundStyle(Color(.textSecondary))
        }
    }

    private var title: String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }
}

/// A sticky day header in Riwayat (D-053): "Kamis, 19 Nov" and the day's pengeluaran, with a separate
/// "+Rp…" in the secondary colour on days with income. The day total lines up with the rows' amounts.
struct HistoryDayHeader: View {
    let day: DayKey
    let totals: HistoryTotals
    let timeZone: TimeZone

    @Environment(\.locale) private var locale

    var body: some View {
        // The amounts move under the date, then onto a line each, instead of shrinking when they don't
        // fit (large text), like the month header.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                titleText
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 8) { amounts }
                    .layoutPriority(1)
            }
            VStack(alignment: .leading, spacing: 2) {
                titleText
                HStack(alignment: .firstTextBaseline, spacing: 8) { amounts }
            }
            VStack(alignment: .leading, spacing: 2) {
                titleText
                amounts
            }
        }
        .textCase(nil)
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.appBackground))
        .listRowInsets(EdgeInsets())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HistoryHeaderLabel.text(title: title, totals: totals))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("history.day")
    }

    private var titleText: some View {
        Text(verbatim: title)
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Color(.textPrimary))
    }

    @ViewBuilder private var amounts: some View {
        if totals.hasIncome {
            AmountText(totals.income, size: .small, showsPlusSign: true)
                .foregroundStyle(Color(.textSecondary))
        }
        if totals.hasExpenses {
            AmountText(totals.expenses, size: .small)
                .foregroundStyle(Color(.textPrimary))
        }
    }

    private var title: String {
        day.start(in: timeZone).formatted(Date.FormatStyle.historyDay(locale: locale, timeZone: timeZone))
    }
}

/// What VoiceOver reads for a month or day header: "Kamis, 19 Nov, pengeluaran 48000 rupiah, pemasukan
/// 8500000 rupiah". A part with nothing in it is left out, except pengeluaran when there is no income either.
private enum HistoryHeaderLabel {
    static func text(title: String, totals: HistoryTotals) -> String {
        var parts = [title]
        if totals.hasExpenses || !totals.hasIncome {
            parts.append(String(
                localized: "pengeluaran \(totals.expenses) rupiah",
                comment: "VoiceOver: a Riwayat month or day header's spending, in whole rupiah."
            ))
        }
        if totals.hasIncome {
            parts.append(String(
                localized: "pemasukan \(totals.income) rupiah",
                comment: "VoiceOver: a Riwayat month or day header's income, in whole rupiah."
            ))
        }
        return parts.joined(separator: ", ")
    }
}
