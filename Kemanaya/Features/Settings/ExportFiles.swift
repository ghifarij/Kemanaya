import CoreTransferable
import Foundation
import KemanayaCore
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// "Ekspor cadangan" (D-060): the backup JSON through the share sheet, which includes "Simpan ke File".
/// The manual path that works even if the folder bookmark doesn't (Phase 12 spike).
///
/// Built lazily: the file is made only when the user picks where it goes, not each time Pengaturan draws.
/// Named `Kemanaya-backup-YYYY-MM-DD.json`, so saving it next to the automatic `Kemanaya-backup.json`
/// never replaces that one.
nonisolated struct BackupExport: Transferable, Sendable {
    let container: ModelContainer

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            SentTransferredFile(try await export.makeFile())
        }
    }

    /// `Kemanaya-backup-2026-11-20.json`, today's date in the device zone.
    static func fileName(now: Date = .now) -> String {
        "Kemanaya-backup-\(ExportFiles.day(of: now)).json"
    }

    private func makeFile() async throws -> URL {
        do {
            let document = try await MainActor.run {
                try Backup.snapshot(of: container.mainContext, exportedAt: .now, appVersion: AutoBackup.appVersion)
            }
            return try ExportFiles.write(try document.encoded(), named: Self.fileName())
        } catch {
            ExportFiles.logger.error("Backup export failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

/// "Ekspor CSV" (D-020, D-060): the window's transactions as `Kemanaya-transaksi-YYYY-MM-DD.csv`, through
/// the share sheet. Built lazily, like ``BackupExport``.
nonisolated struct CSVExport: Transferable, Sendable {
    let container: ModelContainer

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            SentTransferredFile(try await export.makeFile())
        }
    }

    static func fileName(now: Date = .now) -> String {
        TransactionCSV.fileName(now: now, timeZone: .autoupdatingCurrent)
    }

    private func makeFile() async throws -> URL {
        do {
            let now = Date.now
            let data = try await MainActor.run {
                // Subkategori is the name the app shows (D-076), so a seeded Makan reads "Food" in English.
                let rows = try TransactionCSV.rows(in: container.mainContext, now: now, timeZone: .autoupdatingCurrent).map { row in
                    var row = row
                    if let id = row.subcategoryID, let stored = row.subcategoryName {
                        row.subcategoryName = SubcategoryNames.shown(id: id, storedName: stored)
                    }
                    return row
                }
                return TransactionCSV.data(for: rows, timeZone: .autoupdatingCurrent, labels: .app)
            }
            return try ExportFiles.write(data, named: Self.fileName(now: now))
        } catch {
            ExportFiles.logger.error("CSV export failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

/// Shared by the two exports.
nonisolated enum ExportFiles {
    static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Export")

    /// Writes `data` as `name` in a new folder in the temporary directory, so the shared file has exactly
    /// that name and two exports never collide. The system clears the temporary directory.
    static func write(_ data: Data, named name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// `yyyy-MM-dd` of `date` in the device zone, Gregorian (as in ``TransactionCSV/fileName(now:timeZone:)``).
    static func day(of date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent).year().month().day())
    }
}

extension TransactionCSV.Labels {
    /// The app's own words from the String Catalog (D-023), so the file reads like the app. In Indonesian
    /// they equal ``indonesian``, D-060's column names.
    static var app: TransactionCSV.Labels {
        TransactionCSV.Labels(
            header: [
                String(localized: "Tanggal", comment: "Ekspor CSV: column title of the transaction's date (yyyy-MM-dd)."),
                String(localized: "Waktu", comment: "Ekspor CSV: column title of the transaction's time of day (HH:mm)."),
                String(localized: "Jenis", comment: "Ekspor CSV: column title of the kind, Pengeluaran (expense) or Pemasukan (income)."),
                String(localized: "Kelompok", comment: "Ekspor CSV: column title of the expense group, Kebutuhan (needs) or Keinginan (wants); empty for income."),
                String(localized: "Subkategori", comment: "Ekspor CSV: column title of the subcategory name as the app shows it, e.g. Makan."),
                String(localized: "Catatan", comment: "Ekspor CSV: column title of the transaction's optional note."),
                String(localized: "Jumlah", comment: "Ekspor CSV: column title of the amount in whole rupiah, e.g. 45000."),
            ],
            expense: String(localized: TransactionKind.expense.title),
            income: String(localized: TransactionKind.income.title),
            kebutuhan: String(localized: ExpenseGroup.kebutuhan.title),
            keinginan: String(localized: ExpenseGroup.keinginan.title),
            noSubcategory: String(localized: "Tanpa kategori", comment: "Name shown for a transaction whose subcategory no longer exists.")
        )
    }
}
