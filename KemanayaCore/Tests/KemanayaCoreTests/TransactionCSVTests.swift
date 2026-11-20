import Foundation
@testable import KemanayaCore
import SwiftData
import Testing

/// "Ekspor CSV" (D-020, D-060): columns, RFC 4180 quoting, CRLF, UTF-8 with BOM, the time zone, the window.
struct TransactionCSVTests {
    private let labels = TransactionCSV.Labels.indonesian

    /// The file as text, without the BOM.
    private func text(_ data: Data) throws -> String {
        #expect(data.starts(with: [0xEF, 0xBB, 0xBF]), "UTF-8 with a byte order mark")
        return try #require(String(data: data.dropFirst(3), encoding: .utf8))
    }

    @Test func headerAndColumns() throws {
        let rows = [
            TransactionCSV.Row(date: Fixtures.date(2026, 11, 3, 8, 5), kind: .expense, group: .kebutuhan, subcategoryName: "Makan", note: nil, amount: 25_000),
            TransactionCSV.Row(date: Fixtures.date(2026, 11, 4, 18, 30), kind: .expense, group: .keinginan, subcategoryName: "Kopi", note: "Kopi susu", amount: 18_000),
            TransactionCSV.Row(date: Fixtures.date(2026, 11, 5, 9), kind: .income, group: nil, subcategoryName: "Gaji", note: nil, amount: 8_500_000),
            TransactionCSV.Row(date: Fixtures.date(2026, 11, 6, 9), kind: .expense, group: .keinginan, subcategoryName: nil, note: nil, amount: 1_000),
        ]
        let csv = try text(TransactionCSV.data(for: rows, timeZone: Fixtures.jakarta, labels: labels))
        #expect(csv == [
            "Tanggal,Waktu,Jenis,Kelompok,Subkategori,Catatan,Jumlah",
            "2026-11-03,08:05,Pengeluaran,Kebutuhan,Makan,,25000",
            "2026-11-04,18:30,Pengeluaran,Keinginan,Kopi,Kopi susu,18000",
            "2026-11-05,09:00,Pemasukan,,Gaji,,8500000",
            "2026-11-06,09:00,Pengeluaran,Keinginan,Tanpa kategori,,1000",
        ].map { $0 + "\r\n" }.joined(), "CRLF after every line, Jumlah a plain integer")
    }

    @Test func quotingFollowsRFC4180() throws {
        #expect(TransactionCSV.escaped("plain") == "plain")
        #expect(TransactionCSV.escaped("a, b") == "\"a, b\"")
        #expect(TransactionCSV.escaped("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(TransactionCSV.escaped("line\nbreak") == "\"line\nbreak\"")
        #expect(TransactionCSV.escaped("crlf\r\nbreak") == "\"crlf\r\nbreak\"")
        #expect(TransactionCSV.escaped("☕ é") == "☕ é", "emoji and accents need no quoting")

        let row = TransactionCSV.Row(
            date: Fixtures.date(2026, 11, 3), kind: .expense, group: .kebutuhan,
            subcategoryName: "Makan", note: "Nasi, \"padang\"\nenak 🍛", amount: 30_000
        )
        let csv = try text(TransactionCSV.data(for: [row], timeZone: Fixtures.jakarta, labels: labels))
        #expect(csv.hasSuffix("2026-11-03,12:00,Pengeluaran,Kebutuhan,Makan,\"Nasi, \"\"padang\"\"\nenak 🍛\",30000\r\n"))
    }

    /// CSV injection: user text that starts like a formula is written as text; Jumlah is not touched.
    @Test func formulaLikeTextIsNeutralized() throws {
        #expect(TransactionCSV.neutralized("=SUM(A1:A9)") == "'=SUM(A1:A9)")
        #expect(TransactionCSV.neutralized("+62 812") == "'+62 812")
        #expect(TransactionCSV.neutralized("-diskon") == "'-diskon")
        #expect(TransactionCSV.neutralized("@kantor") == "'@kantor")
        #expect(TransactionCSV.neutralized("Nasi = enak") == "Nasi = enak", "only the first character counts")
        #expect(TransactionCSV.neutralized("") == "")

        let rows = [
            TransactionCSV.Row(
                date: Fixtures.date(2026, 11, 3), kind: .expense, group: .keinginan,
                subcategoryName: "@Hobi", note: "=HYPERLINK(\"http://x\",\"a\")", amount: 30_000
            ),
            TransactionCSV.Row(
                date: Fixtures.date(2026, 11, 4), kind: .expense, group: .keinginan,
                subcategoryName: "-Lain", note: "+1, -1", amount: 1_000
            ),
        ]
        let csv = try text(TransactionCSV.data(for: rows, timeZone: Fixtures.jakarta, labels: labels))
        #expect(csv.contains("\r\n2026-11-03,12:00,Pengeluaran,Keinginan,'@Hobi,\"'=HYPERLINK(\"\"http://x\"\",\"\"a\"\")\",30000\r\n"))
        #expect(csv.contains("\r\n2026-11-04,12:00,Pengeluaran,Keinginan,'-Lain,\"'+1, -1\",1000\r\n"))
    }

    @Test func datesAndTimesAreInTheGivenZone() throws {
        // 00:30 on 1 November in Jakarta is still 31 October in Los Angeles.
        let row = TransactionCSV.Row(
            date: Fixtures.date(2026, 11, 1, 0, 30), kind: .expense, group: .kebutuhan,
            subcategoryName: "Makan", note: nil, amount: 1
        )
        let jakarta = try text(TransactionCSV.data(for: [row], timeZone: Fixtures.jakarta, labels: labels))
        let losAngeles = try text(TransactionCSV.data(for: [row], timeZone: Fixtures.losAngeles, labels: labels))
        #expect(jakarta.contains("\r\n2026-11-01,00:30,"))
        #expect(losAngeles.contains("\r\n2026-10-31,10:30,"))

        #expect(TransactionCSV.fileName(now: Fixtures.date(2026, 11, 1, 0, 30), timeZone: Fixtures.jakarta) == "Kemanaya-transaksi-2026-11-01.csv")
        #expect(TransactionCSV.fileName(now: Fixtures.date(2026, 11, 1, 0, 30), timeZone: Fixtures.losAngeles) == "Kemanaya-transaksi-2026-10-31.csv")
    }

    /// From the store: only the raw window, oldest first, the subcategory's current name.
    @Test func exportsTheWindowOldestFirst() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let makan = try store.subcategory(named: "Makan")
        let gaji = try store.subcategory(named: "Gaji")
        let now = Fixtures.date(2026, 11, 20)
        store.context.insert(MoneyTransaction(amount: 1, subcategory: makan, date: Fixtures.date(2025, 10, 31, 23, 59)))
        store.context.insert(MoneyTransaction(amount: 3, subcategory: gaji, date: Fixtures.date(2026, 11, 2)))
        store.context.insert(MoneyTransaction(amount: 2, subcategory: makan, date: Fixtures.date(2025, 11, 1, 0)))
        try store.context.save()

        let rows = try TransactionCSV.rows(in: store.context, now: now, timeZone: Fixtures.jakarta)
        #expect(rows.map(\.amount) == [2, 3], "October 2025 is before the window; oldest first")
        #expect(rows.map(\.subcategoryName) == ["Makan", "Gaji"])

        let csv = try text(TransactionCSV.data(in: store.context, now: now, timeZone: Fixtures.jakarta, labels: labels))
        #expect(csv.components(separatedBy: "\r\n").count == 4, "header, two rows, and the empty string after the last CRLF")
    }

    @Test func anEmptyExportIsJustTheHeader() throws {
        let csv = try text(TransactionCSV.data(for: [], timeZone: Fixtures.jakarta, labels: labels))
        #expect(csv == "Tanggal,Waktu,Jenis,Kelompok,Subkategori,Catatan,Jumlah\r\n")
    }
}
