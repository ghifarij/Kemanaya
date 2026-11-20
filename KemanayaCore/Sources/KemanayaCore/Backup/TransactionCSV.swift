import Foundation
import SwiftData

/// "Ekspor CSV" (D-020, D-060): the raw transactions of the window in one spreadsheet file.
///
/// - Rows: every transaction from the raw window's start (D-017), oldest first. No upper bound, like
///   Riwayat (D-057), so nothing logged is left out. Rollups are not included; the yearly recap covers them.
/// - Columns: Tanggal (`yyyy-MM-dd`), Waktu (`HH:mm`), Jenis, Kelompok, Subkategori, Catatan, Jumlah. Dates
///   and times are in the given zone on the Gregorian calendar, whatever the device's calendar system.
///   Jumlah is the plain rupiah integer (`45000`), always positive: Jenis says which way the money went.
/// - Format: RFC 4180 (fields with a comma, quote, CR or LF are quoted, quotes doubled), CRLF line
///   endings, UTF-8 with a byte order mark so Excel shows emoji and accents.
/// - Words: the header and the Jenis / Kelompok values come from ``Labels``. The app passes its own display
///   names from the String Catalog (D-023), so the file reads like the app; ``Labels/indonesian`` is the
///   Indonesian source text, used by tests and as the reference.
public enum TransactionCSV {
    /// The words written into the file.
    public struct Labels: Sendable {
        /// The seven column titles, in order.
        public var header: [String]
        public var expense: String
        public var income: String
        public var kebutuhan: String
        public var keinginan: String
        /// Subkategori of a transaction whose subcategory no longer exists (D-006).
        public var noSubcategory: String

        public init(header: [String], expense: String, income: String, kebutuhan: String, keinginan: String, noSubcategory: String) {
            precondition(header.count == 7, "Tanggal, Waktu, Jenis, Kelompok, Subkategori, Catatan, Jumlah")
            self.header = header
            self.expense = expense
            self.income = income
            self.kebutuhan = kebutuhan
            self.keinginan = keinginan
            self.noSubcategory = noSubcategory
        }

        /// D-060's column names and the app's Indonesian display names.
        public static let indonesian = Labels(
            header: ["Tanggal", "Waktu", "Jenis", "Kelompok", "Subkategori", "Catatan", "Jumlah"],
            expense: "Pengeluaran",
            income: "Pemasukan",
            kebutuhan: "Kebutuhan",
            keinginan: "Keinginan",
            noSubcategory: "Tanpa kategori"
        )

        func name(of kind: TransactionKind) -> String {
            switch kind {
            case .expense: expense
            case .income: income
            }
        }

        func name(of group: ExpenseGroup?) -> String {
            switch group {
            case .kebutuhan: kebutuhan
            case .keinginan: keinginan
            case nil: ""
            }
        }
    }

    /// One transaction as the file needs it.
    public struct Row: Equatable, Sendable {
        public var date: Date
        public var kind: TransactionKind
        public var group: ExpenseGroup?
        /// Nil for an orphan (D-006).
        public var subcategoryName: String?
        public var note: String?
        public var amount: Int64

        public init(date: Date, kind: TransactionKind, group: ExpenseGroup?, subcategoryName: String?, note: String?, amount: Int64) {
            self.date = date
            self.kind = kind
            self.group = group
            self.subcategoryName = subcategoryName
            self.note = note
            self.amount = amount
        }
    }

    /// `Kemanaya-transaksi-YYYY-MM-DD.csv`, the date being `now` in `timeZone`.
    public static func fileName(now: Date, timeZone: TimeZone) -> String {
        "Kemanaya-transaksi-\(day(of: now, in: timeZone)).csv"
    }

    /// The window's transactions in `context`, oldest first (ties by creation, then id).
    public static func rows(in context: ModelContext, now: Date, timeZone: TimeZone) throws -> [Row] {
        let start = RetentionWindow.rawWindowStart(now: now, timeZone: timeZone)
        let descriptor = FetchDescriptor<MoneyTransaction>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
            .sorted { ($0.date, $0.createdAt, $0.id.uuidString) < ($1.date, $1.createdAt, $1.id.uuidString) }
            .map { transaction in
                Row(
                    date: transaction.date,
                    kind: transaction.kind,
                    group: transaction.group,
                    subcategoryName: transaction.subcategory?.name,
                    note: transaction.note,
                    amount: transaction.amount
                )
            }
    }

    /// The file for the window's transactions in `context`.
    public static func data(in context: ModelContext, now: Date, timeZone: TimeZone, labels: Labels) throws -> Data {
        data(for: try rows(in: context, now: now, timeZone: timeZone), timeZone: timeZone, labels: labels)
    }

    /// The file's bytes for `rows`, in the order given: BOM, header, one line per row, each ending in CRLF.
    public static func data(for rows: [Row], timeZone: TimeZone, labels: Labels) -> Data {
        let calendar = Calendar.gregorian(in: timeZone)
        var lines = [labels.header.map(escaped).joined(separator: ",")]
        for row in rows {
            let time = calendar.dateComponents([.hour, .minute], from: row.date)
            let fields = [
                day(of: row.date, in: timeZone),
                String(format: "%02ld:%02ld", time.hour!, time.minute!),
                labels.name(of: row.kind),
                labels.name(of: row.group),
                row.subcategoryName ?? labels.noSubcategory,
                row.note ?? "",
                String(row.amount),
            ]
            lines.append(fields.map(escaped).joined(separator: ","))
        }
        let text = lines.map { $0 + "\r\n" }.joined()
        return Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    /// RFC 4180: quoted when it holds a comma, a quote, CR or LF; quotes inside are doubled.
    static func escaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\r" || $0 == "\n" || $0 == "\r\n" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// `yyyy-MM-dd` of `date` in `timeZone`, Gregorian.
    private static func day(of date: Date, in timeZone: TimeZone) -> String {
        let parts = Calendar.gregorian(in: timeZone).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year!, parts.month!, parts.day!)
    }
}
