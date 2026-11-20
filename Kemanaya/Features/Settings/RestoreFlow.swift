import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// "Pulihkan dari cadangan" (D-060), shared by Pengaturan and Home's fresh-install empty state: a picked
/// file is read and checked, an alert asks "Ganti semua data dengan cadangan ini?" with the backup's date
/// and transaction count, and confirming replaces everything in one save, then runs retention (D-059).
///
/// A screen owns one controller, presents its own `.fileImporter` for JSON and passes the result to
/// ``open(_:)``, attaches ``SwiftUI/View/restoreConfirmation(_:)`` and shows ``RestoreStatusText``
/// inline. Nothing changes until the user confirms, and a refused file or failed save changes nothing.
@Observable
final class RestoreController {
    enum Status: Equatable {
        case idle
        case reading
        /// Restored; the number of transactions in the file.
        case restored(Int)
        case failed(Failure)
    }

    nonisolated enum Failure: Error, Equatable {
        /// The file couldn't be opened or read.
        case unreadableFile
        /// Written by a newer app version.
        case newerFormat
        /// Not a Kemanaya backup, or its content is invalid.
        case invalid
        /// The restore's save failed and was rolled back.
        case saveFailed
    }

    /// A checked backup waiting for the user's confirmation.
    struct Pending: Identifiable {
        let id = UUID()
        let document: BackupDocument
    }

    /// Set while the confirmation alert is up.
    var pending: Pending?
    private(set) var status = Status.idle

    private nonisolated static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Restore")

    /// Reads and checks the file the importer picked; on success asks for confirmation.
    func open(_ result: Result<URL, any Error>) {
        switch result {
        case .failure(let error):
            Self.logger.error("Backup picker failed: \(error.localizedDescription, privacy: .public)")
            status = .failed(.unreadableFile)
        case .success(let url):
            status = .reading
            Task {
                switch await Self.read(url) {
                case .success(let document):
                    status = .idle
                    pending = Pending(document: document)
                case .failure(let failure):
                    status = .failed(failure)
                }
            }
        }
    }

    /// Replaces all data with `pending`'s backup, then runs retention.
    func confirm(_ pending: Pending, in context: ModelContext) {
        self.pending = nil
        do {
            try Backup.restore(pending.document, into: context)
        } catch let error as BackupError {
            Self.logger.error("Restore refused: \(String(describing: error), privacy: .public)")
            status = .failed(error.isNewerFormat ? .newerFormat : .invalid)
            return
        } catch {
            Self.logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            status = .failed(.saveFailed)
            return
        }
        Self.logger.info("Restored a backup with \(pending.document.transactions.count) transactions")
        // An old backup can hold months before the raw window (D-059).
        RetentionRunner.run(in: context)
        status = .restored(pending.document.transactions.count)
    }

    func cancel() {
        pending = nil
    }

    /// Reads (coordinated, so an iCloud file is downloaded first) and decodes, off the main actor.
    private nonisolated static func read(_ url: URL) async -> Result<BackupDocument, Failure> {
        await Task.detached(priority: .userInitiated) {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            var coordinationError: NSError?
            var data: Data?
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
                data = try? Data(contentsOf: url)
            }
            guard let data else {
                logger.error("Backup file unreadable: \(coordinationError?.localizedDescription ?? "no data", privacy: .public)")
                return .failure(.unreadableFile)
            }
            do throws(BackupError) {
                return .success(try BackupDocument.decode(data))
            } catch {
                logger.error("Backup file refused: \(String(describing: error), privacy: .public)")
                return .failure(error.isNewerFormat ? .newerFormat : .invalid)
            }
        }.value
    }
}

extension View {
    /// The "Ganti semua data dengan cadangan ini?" alert for `controller`'s pending backup.
    func restoreConfirmation(_ controller: RestoreController) -> some View {
        modifier(RestoreConfirmation(controller: controller))
    }
}

private struct RestoreConfirmation: ViewModifier {
    let controller: RestoreController

    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content
            // An alert, not a confirmationDialog, as for deleting a transaction (TransactionActions):
            // centred and full-width at every text size on iOS 18 and 26.
            .alert(
                Text("Ganti semua data dengan cadangan ini?", comment: "Title of the alert confirming a restore from a backup file: all data in the app is replaced."),
                isPresented: Binding(
                    get: { controller.pending != nil },
                    set: { if !$0 { controller.cancel() } }
                ),
                presenting: controller.pending
            ) { pending in
                Button(role: .destructive) {
                    controller.confirm(pending, in: context)
                } label: {
                    Text("Ganti", comment: "Restore alert: the button that replaces all data with the backup.")
                }
                .accessibilityIdentifier("restore.confirm")
                Button(role: .cancel) {
                    controller.cancel()
                } label: {
                    Text("Batal", comment: "Cancels: closes the add sheet without saving, or the delete dialog without deleting.")
                }
            } message: { pending in
                let preview = pending.document.preview
                let date = preview.exportedAt.formatted(
                    Date.FormatStyle.gregorian(locale: locale).day().month(.wide).year().hour().minute()
                )
                Text(
                    "Cadangan dari \(date) berisi \(preview.transactionCount) transaksi. Semua data di aplikasi ini akan diganti.",
                    comment: "Restore alert message. 1: when the backup was made, e.g. '20 November 2026 14.05'. 2: how many transactions it holds. Everything in the app is replaced."
                )
            }
    }
}

/// The restore's progress or result, inline under the row that started it (never an alert, D-060).
struct RestoreStatusText: View {
    let status: RestoreController.Status

    var body: some View {
        if let text {
            text
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("restore.status")
        }
    }

    private var text: Text? {
        switch status {
        case .idle:
            nil
        case .reading:
            Text("Membaca cadangan…", comment: "Inline status while a picked backup file is read and checked.")
        case .restored(let count):
            Text("Data dipulihkan dari cadangan (\(count) transaksi).", comment: "Inline result after a restore. The number is how many transactions the backup held.")
        case .failed(.newerFormat):
            Text(
                "Cadangan ini dibuat oleh versi Kemanaya yang lebih baru. Perbarui aplikasinya dulu. Datamu tidak berubah.",
                comment: "Inline error: the backup file was made by a newer app version. Nothing was changed."
            )
        case .failed(.invalid):
            Text(
                "Berkas ini bukan cadangan Kemanaya yang valid. Datamu tidak berubah.",
                comment: "Inline error: the picked file is not a valid Kemanaya backup. Nothing was changed."
            )
        case .failed(.unreadableFile):
            Text(
                "Berkas tidak bisa dibuka. Datamu tidak berubah.",
                comment: "Inline error: the picked backup file could not be opened or read. Nothing was changed."
            )
        case .failed(.saveFailed):
            Text(
                "Pemulihan gagal disimpan. Datamu tidak berubah.",
                comment: "Inline error: restoring the backup failed while saving and was undone. Nothing was changed."
            )
        }
    }
}
