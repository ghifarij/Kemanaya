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

/// A sticky day header in Riwayat and Home's month list (D-053, D-073, D-079): the date, e.g.
/// "Kamis, 19 Nov", and on the trailing side an ⓘ whose popover says how to reach Ubah and Hapus: rows
/// open by swipe only (D-079). No day total: next to the month's "Pengeluaran" figure it read as a
/// second, competing total (D-073).
struct HistoryDayHeader: View {
    let day: DayKey
    let timeZone: TimeZone

    @Environment(\.locale) private var locale
    @State private var showsHint = false

    var body: some View {
        HStack(spacing: 4) {
            Text(verbatim: title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color(.textPrimary))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("history.day")
            infoButton
        }
        .textCase(nil)
        // The ⓘ's 44 pt target ends at the edge, so its glyph lines up with the rows' amounts.
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .background(Color(.appBackground))
        .listRowInsets(EdgeInsets())
    }

    /// ⓘ: a popover (on iPhone too, not a sheet) with one line, "Geser untuk ubah atau hapus" (D-079).
    private var infoButton: some View {
        Button {
            showsHint = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(Color(.textSecondary))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Info", comment: "VoiceOver label of the ⓘ button on a Riwayat day header (D-079): it shows how to change or delete a transaction."))
        .accessibilityHint(Text(swipeHint))
        .accessibilityIdentifier("history.day.info")
        .popover(isPresented: $showsHint) {
            SwipeHintPopover()
                .presentationCompactAdaptation(.popover)
        }
    }

    private var swipeHint: LocalizedStringResource {
        SwipeHintPopover.text
    }

    private var title: String {
        day.start(in: timeZone).formatted(Date.FormatStyle.historyDay(locale: locale, timeZone: timeZone))
    }
}

/// The day header ⓘ's popover (D-079): one line of neutral text saying that a row's actions are a swipe away.
struct SwipeHintPopover: View {
    static let text = LocalizedStringResource(
        "Geser untuk ubah atau hapus",
        comment: "Riwayat day header ⓘ popover and its VoiceOver hint (D-079): transaction rows open by swipe only; swiping shows Ubah (edit) and Hapus (delete)."
    )

    var body: some View {
        Text(Self.text)
            .font(.subheadline)
            .foregroundStyle(Color(.textPrimary))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 320, alignment: .leading)
            .accessibilityIdentifier("history.day.hint")
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
            Text(verbatim: "A day: the date and its ⓘ")
        } header: {
            HistoryDayHeader(day: DayKey(year: 2026, month: 11, day: 19), timeZone: zone)
        }
    }
    .listStyle(.plain)
    .foregroundStyle(Color(.textPrimary))
    .background(Color(.appBackground))
}

#Preview("Swipe hint popover") {
    SwipeHintPopover()
        .background(Color(.surface))
        .padding()
        .background(Color(.appBackground))
}

#Preview("Day headers with ⓘ") {
    let zone = TimeZone.autoupdatingCurrent
    List {
        ForEach([19, 18], id: \.self) { day in
            Section {
                Text(verbatim: "☕ Kopi · Rp18.000")
                Text(verbatim: "🍚 Makan · Rp30.000")
            } header: {
                HistoryDayHeader(day: DayKey(year: 2026, month: 11, day: day), timeZone: zone)
            }
        }
    }
    .listStyle(.plain)
    .foregroundStyle(Color(.textPrimary))
    .background(Color(.appBackground))
}
