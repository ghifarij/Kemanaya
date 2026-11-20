import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// "Pulihkan dari cadangan" (D-060), shared by Pengaturan and Home's fresh-install empty state: a picked
/// file is read and checked, an alert asks "Ganti semua data dengan cadangan ini?" with the backup's date
/// and transaction count, and confirming replaces everything in one save, then runs retention (D-059).
///
/// `RootView` owns the one controller, puts it in the environment and attaches
/// ``SwiftUI/View/restoreConfirmation(_:)`` once. A screen presents its own `.fileImporter` for JSON,
/// passes the result to ``open(_:from:)`` with its ``Origin``, and shows ``RestoreStatusText`` for
/// ``status(for:)`` inline. Nothing changes until the user confirms, and a refused file or failed save
/// changes nothing.
///
/// - **Before replacing:** ``AutoBackup/beginRestore()`` writes the current data as
///   `Kemanaya-backup-before-restore.json` (when a folder is set) and holds automatic writes meanwhile.
/// - **After a restore** ``generation`` goes up: `RootView` rebuilds every tab's content with it, so no
///   open screen or sheet keeps a model the restore deleted. The selected tab stays, and the status
///   lives here, so the screen that started the restore still shows its result.
@Observable
final class RestoreController {
    enum Status: Equatable {
        case idle
        case reading
        /// Writing the before-restore copy and replacing the data.
        case restoring
        /// Restored; the number of transactions in the file.
        case restored(Int)
        case failed(Failure)
    }

    /// The screen a restore was started from: only it shows the status.
    enum Origin: Equatable {
        case home, settings
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
    /// Where the current ``status`` belongs.
    private(set) var origin: Origin?
    /// Goes up after every successful restore; the tabs use it as their identity.
    private(set) var generation = 0

    private nonisolated static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Restore")

    /// `origin`'s status: the current one if `origin` started it, otherwise idle.
    func status(for origin: Origin) -> Status {
        self.origin == origin ? status : .idle
    }

    /// Reads and checks the file the importer picked on `origin`; on success asks for confirmation.
    func open(_ result: Result<URL, any Error>, from origin: Origin) {
        self.origin = origin
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

    /// Writes the before-restore copy, replaces all data with `pending`'s backup, runs retention and
    /// moves to the next ``generation``.
    func confirm(_ pending: Pending, in context: ModelContext, autoBackup: AutoBackup) async {
        self.pending = nil
        status = .restoring
        await autoBackup.beginRestore()
        defer { autoBackup.endRestore() }
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
        generation += 1
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
    @Environment(AutoBackup.self) private var autoBackup

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
                    Task { await controller.confirm(pending, in: context, autoBackup: autoBackup) }
                } label: {
                    Text("Ganti", comment: "Restore alert: the button that replaces all data with the backup.")
                }
                .accessibilityIdentifier("restore.confirm")
                Button(role: .cancel) {
                    controller.cancel()
                } label: {
                    Text("Batal", comment: "Cancels: closes a sheet or dialog without saving, deleting or restoring (the add sheet, the delete dialogs, the restore alert, the budget sheet and the subcategory editor).")
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
        case .restoring:
            Text("Memulihkan…", comment: "Inline status while the data is being replaced by the confirmed backup.")
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
