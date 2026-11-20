import KemanayaCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The Pengaturan tab (D-060). For now one section, **Cadangan & Ekspor**: the automatic backup folder
/// (D-019) with its last backup or last error, "Cadangkan sekarang", the manual "Ekspor cadangan",
/// "Pulihkan dari cadangan" and "Ekspor CSV" (D-020). Subcategories and budgets join in Phase 10.
///
/// Native `Form` styling. Status and errors are inline secondary text, never alerts; the only alert is
/// the restore confirmation.
struct SettingsView: View {
    /// What the one file importer is open for. One importer per screen: two on the same screen can
    /// stop each other from presenting.
    private enum ImportTarget {
        case folder, backup
    }

    @Environment(AutoBackup.self) private var autoBackup
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var restore = RestoreController()
    @State private var importTarget = ImportTarget.backup
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    folderRow
                    if autoBackup.hasFolder {
                        backUpNowRow
                        turnOffRow
                    }
                    exportBackupRow
                    restoreRow
                    exportCSVRow
                } header: {
                    Text("Cadangan & Ekspor", comment: "Pengaturan: header of the backup and export section.")
                } footer: {
                    Text(
                        "Cadangan berisi semua datamu: transaksi, kategori, pin, anggaran, dan rekap bulanan. Simpan di iCloud Drive agar tetap aman walau aplikasi dihapus.",
                        comment: "Pengaturan: footer of the backup and export section, explaining what a backup holds and why iCloud Drive."
                    )
                }
            }
            .accessibilityIdentifier("settings.form")
            .navigationTitle(Text("Pengaturan", comment: "Title of the Pengaturan (settings) tab and its tab bar item."))
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: importTarget == .folder ? [.folder] : [.json]
            ) { result in
                switch importTarget {
                case .folder:
                    if case .success(let url) = result { autoBackup.chooseFolder(url) }
                case .backup:
                    restore.open(result)
                }
            }
            .restoreConfirmation(restore)
        }
    }

    // MARK: - Rows

    /// Pick or change the folder; shows its name and the last backup, or the last error.
    private var folderRow: some View {
        Button {
            importTarget = .folder
            isImporting = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text("Folder cadangan otomatis", comment: "Pengaturan: row that picks or changes the folder the automatic backup is written to.")
                } icon: {
                    Image(systemName: "folder")
                }
                folderDetail
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.backupStatus")
            }
        }
        .accessibilityHint(Text(
            "Pilih folder untuk cadangan otomatis.",
            comment: "VoiceOver hint of the backup folder row: opens the folder picker."
        ))
        .accessibilityIdentifier("settings.backupFolder")
    }

    @ViewBuilder private var folderDetail: some View {
        if let name = autoBackup.folderName {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .foregroundStyle(Color(.textPrimary))
                backupStatus
            }
        } else {
            Text(
                "Belum dipilih. Pilih folder, misalnya di iCloud Drive, agar cadangan tetap ada walau aplikasi dihapus.",
                comment: "Pengaturan: under the backup folder row when no folder is chosen yet (automatic backup is off)."
            )
        }
    }

    @ViewBuilder private var backupStatus: some View {
        if autoBackup.isWriting {
            Text("Mencadangkan…", comment: "Pengaturan: inline status while the automatic backup is being written.")
        } else if let failure = autoBackup.lastFailure {
            failureText(failure)
        } else if autoBackup.keptExistingBackup {
            Text(
                "Cadangan yang sudah ada di folder ini tidak ditimpa karena aplikasi masih kosong. Pulihkan dulu, atau mulai mencatat.",
                comment: "Pengaturan: the app has no data yet, so the backup already in the folder was kept instead of being overwritten."
            )
        } else if let date = autoBackup.lastSuccess {
            Text(
                "Terakhir dicadangkan \(date.formatted(Date.FormatStyle.gregorian(locale: locale).day().month(.abbreviated).year().hour().minute()))",
                comment: "Pengaturan: when the last automatic backup was written, e.g. '20 Nov 2026 14.05'."
            )
        } else {
            Text("Belum ada cadangan.", comment: "Pengaturan: a folder is chosen but no backup has been written yet.")
        }
    }

    private func failureText(_ failure: AutoBackup.Failure) -> Text {
        switch failure {
        case .folderUnavailable:
            Text(
                "Folder tidak bisa dibuka. Pilih ulang foldernya.",
                comment: "Pengaturan: inline error, the backup folder can no longer be opened (moved, deleted or access removed). Asks to pick it again."
            )
        case .writeFailed:
            Text(
                "Cadangan terakhir gagal disimpan. Dicoba lagi saat ada perubahan.",
                comment: "Pengaturan: inline error, the last automatic backup could not be written; it is retried on the next change."
            )
        case .snapshotFailed:
            Text(
                "Data tidak bisa dibaca untuk dicadangkan. Dicoba lagi saat ada perubahan.",
                comment: "Pengaturan: inline error, the data could not be read for the backup; it is retried on the next change."
            )
        }
    }

    private var backUpNowRow: some View {
        Button {
            Task { await autoBackup.backUpNow() }
        } label: {
            HStack {
                Label {
                    Text("Cadangkan sekarang", comment: "Pengaturan: button that writes the automatic backup right away.")
                } icon: {
                    Image(systemName: "arrow.clockwise.icloud")
                }
                if autoBackup.isWriting {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(autoBackup.isWriting)
        .accessibilityIdentifier("settings.backupNow")
    }

    private var turnOffRow: some View {
        Button(role: .destructive) {
            autoBackup.forgetFolder()
        } label: {
            Label {
                Text("Matikan cadangan otomatis", comment: "Pengaturan: button that turns automatic backup off by forgetting the folder. Files already there stay.")
            } icon: {
                Image(systemName: "xmark.circle")
            }
        }
        .accessibilityIdentifier("settings.backupOff")
    }

    private var exportBackupRow: some View {
        ShareLink(
            item: BackupExport(container: context.container),
            preview: SharePreview(BackupExport.fileName(), image: Image(systemName: "doc"))
        ) {
            Label {
                Text("Ekspor cadangan", comment: "Pengaturan: shares the backup file (share sheet, including Save to Files).")
            } icon: {
                Image(systemName: "square.and.arrow.up")
            }
        }
        .accessibilityIdentifier("settings.exportBackup")
    }

    private var restoreRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                importTarget = .backup
                isImporting = true
            } label: {
                Label {
                    Text("Pulihkan dari cadangan", comment: "Restores all data from a backup file: Pengaturan's row and the link in Home's empty state on a fresh install.")
                } icon: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .accessibilityIdentifier("settings.restore")
            RestoreStatusText(status: restore.status)
        }
    }

    private var exportCSVRow: some View {
        ShareLink(
            item: CSVExport(container: context.container),
            preview: SharePreview(CSVExport.fileName(), image: Image(systemName: "tablecells"))
        ) {
            Label {
                Text("Ekspor CSV", comment: "Pengaturan: shares the last 13 months of transactions as a CSV spreadsheet file.")
            } icon: {
                Image(systemName: "tablecells")
            }
        }
        .accessibilityIdentifier("settings.exportCSV")
    }
}

#if DEBUG
#Preview {
    let container = PreviewStore.makeContainer()
    SettingsView()
        .modelContainer(container)
        .environment(AutoBackup(container: container, defaults: nil))
}
#endif
