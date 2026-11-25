import KemanayaCore
import SwiftUI

/// Display names of domain values. One place, so every screen uses the same catalog key and
/// translator comment (D-023). Subcategory names are user data and never go through the catalog.
extension ExpenseGroup {
    /// "Kebutuhan" / "Keinginan" (D-003).
    var title: LocalizedStringResource {
        switch self {
        case .kebutuhan: LocalizedStringResource(
            "Kebutuhan",
            comment: "Name of the needs expense group: the needs/wants bar legend and the add sheet's section header."
        )
        case .keinginan: LocalizedStringResource(
            "Keinginan",
            comment: "Name of the wants expense group: the needs/wants bar legend and the add sheet's section header."
        )
        }
    }
}

extension TransactionKind {
    /// "Pengeluaran" / "Pemasukan" (D-002).
    var title: LocalizedStringResource {
        switch self {
        case .expense: LocalizedStringResource(
            "Pengeluaran",
            comment: "Expense, money going out, as a kind: a segment of the expense/income switch (add sheet, Kelola subkategori) and the Jenis value in the CSV export."
        )
        case .income: LocalizedStringResource(
            "Pemasukan",
            comment: "Income, money coming in, as a kind: a segment of the expense/income switch (add sheet, Kelola subkategori), the income section of Atur kartu, and the Jenis value in the CSV export."
        )
        }
    }

    /// "Pengeluaran" / "Pemasukan" as the caption of a total or a chart series (D-065): its own key, so
    /// English can say "Expenses" here while a segment or CSV value says "Expense".
    var captionTitle: LocalizedStringResource {
        switch self {
        case .expense: LocalizedStringResource(
            "kind.caption.expense",
            defaultValue: "Pengeluaran",
            comment: "Caption of a spending total or chart series: the yearly recap's total, the Analisis donut centre, the six-month chart legend, and the label of the spending figure in Riwayat's month and day headers (D-073). Plural sense in English (Expenses)."
        )
        case .income: LocalizedStringResource(
            "kind.caption.income",
            defaultValue: "Pemasukan",
            comment: "Caption of an income total or chart series: the yearly recap's total, the six-month chart legend, and the label of the income figure in a Riwayat month header (D-073)."
        )
        }
    }
}

/// A share of spending, labelled (D-073): "73% dari total", never a bare "%".
enum ShareCopy {
    /// "73% dari total" ("73% of total"): Analisis's and the yearly recap's ranked rows.
    /// - Parameters:
    ///   - percent: whole percent.
    ///   - isUnderOnePercent: a share above zero that rounds to 0, shown as "<1% dari total".
    static func ofTotal(percent: Int, isUnderOnePercent: Bool = false, locale: Locale) -> Text {
        let share = isUnderOnePercent
            ? String(localized: "<1%", comment: "A share of spending under one percent: Analisis and the yearly recap's ranked rows, inside '<1% dari total'.")
            : percent.formatted(.percent.locale(locale))
        return Text(
            "\(share) dari total",
            comment: "A share of the month's or year's total spending, e.g. '73% dari total' ('73% of total'): Analisis's and the yearly recap's ranked rows (D-073). The placeholder is the percent with its sign, e.g. '73%' or '<1%'."
        )
    }
}

extension PinSection {
    /// "Kebutuhan" / "Keinginan" / "Pemasukan": the same keys as the group and kind names (D-068).
    var title: LocalizedStringResource {
        switch self {
        case .kebutuhan: ExpenseGroup.kebutuhan.title
        case .keinginan: ExpenseGroup.keinginan.title
        case .pemasukan: TransactionKind.income.title
        }
    }

    /// The expense group of a column section, nil for income.
    var group: ExpenseGroup? {
        switch self {
        case .kebutuhan: .kebutuhan
        case .keinginan: .keinginan
        case .pemasukan: nil
        }
    }
}

extension MoneyTransaction {
    /// The subcategory's name, or "Tanpa kategori" for a transaction whose subcategory was deleted,
    /// which the app avoids (D-006).
    var displayName: String {
        subcategory?.name ?? String(
            localized: "Tanpa kategori",
            comment: "Name shown for a transaction whose subcategory no longer exists."
        )
    }

    /// The subcategory's emoji, or ❔ when it is gone.
    var displayEmoji: String {
        subcategory?.emoji ?? "❔"
    }
}

extension Date.FormatStyle {
    /// A date format on the Gregorian calendar, whatever calendar system the device uses.
    ///
    /// A month title must pass the zone its ``MonthKey`` was bucketed in (`month.start(in: timeZone)`),
    /// so the start instant formats as that month even when the device zone differs. Raw dates (a
    /// transaction's time) keep the device zone. Add fields to it, e.g.
    /// `.gregorian(locale: locale, timeZone: timeZone).month(.wide).year()`.
    static func gregorian(locale: Locale, timeZone: TimeZone = .autoupdatingCurrent) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: .gregorian(in: timeZone), timeZone: timeZone)
    }

    /// A Riwayat day header's date, e.g. "Kamis, 19 Nov" in Indonesian (D-053): the weekday, the day and
    /// the short month. Format ``DayKey/start(in:)`` with the zone the day was bucketed in, like a month title.
    static func historyDay(locale: Locale, timeZone: TimeZone) -> Date.FormatStyle {
        gregorian(locale: locale, timeZone: timeZone).weekday(.wide).day().month(.abbreviated)
    }
}
