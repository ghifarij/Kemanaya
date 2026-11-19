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
            comment: "Expense, money going out. A segment of the add sheet's expense/income switch."
        )
        case .income: LocalizedStringResource(
            "Pemasukan",
            comment: "Income, money coming in. A segment of the add sheet's expense/income switch."
        )
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
}
