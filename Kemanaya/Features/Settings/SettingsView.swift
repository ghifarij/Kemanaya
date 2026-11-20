import KemanayaCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The Pengaturan tab (D-060, D-062), top to bottom:
/// - **Anggaran**: the Kebutuhan and Keinginan budgets (D-010, D-041), each opening ``BudgetAmountSheet``.
/// - **Subkategori**: "Kelola subkategori" pushes ``SubcategoryListView``.
/// - **Cadangan & Ekspor** (D-060, unchanged): the automatic backup folder (D-019) with its last backup or
///   last error, "Cadangkan sekarang", the manual "Ekspor cadangan", "Pulihkan dari cadangan" and "Ekspor CSV" (D-020).
/// - **Tentang**: the app version, and "Lihat pengenalan lagi", which shows the introduction again (D-063).
///
/// Native `Form` styling. Status and errors are inline secondary text, never alerts; the only alerts are
/// the restore confirmation and a failed budget save.
struct SettingsView: View {
    /// What the one file importer is open for. One importer per screen: two on the same screen can
    /// stop each other from presenting.
    private enum ImportTarget {
        case folder, backup
    }

    @Environment(AutoBackup.self) private var autoBackup
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    /// Shared with Home's empty state; its alert is in `RootView`.
    @Environment(RestoreController.self) private var restore
    @State private var importTarget = ImportTarget.backup
    @State private var isImporting = false
    /// The settings row, as ``AppSettings/fetchOrCreate(in:)`` picks it; none until the first write.
    @Query(sort: \AppSettings.seedVersion, order: .reverse) private var settings: [AppSettings]
    /// The group whose budget sheet is open.
    @State private var budgetRoute: GroupBudgetRoute?

    /// Shows onboarding again ("Lihat pengenalan lagi", D-063); `RootView` passes it. Without it (previews)
    /// the row isn't shown, so there is never a button that does nothing.
    private let onShowIntroduction: (() -> Void)?

    init(onShowIntroduction: (() -> Void)? = nil) {
        self.onShowIntroduction = onShowIntroduction
    }

    var body: some View {
        NavigationStack {
            Form {
                budgetSection
                subcategorySection
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
                aboutSection
            }
            .accessibilityIdentifier("settings.form")
            .sheet(item: $budgetRoute) { route in
                groupBudgetSheet(route.group)
            }
            .navigationTitle(Text("Pengaturan", comment: "Title of the Pengaturan (settings) tab and its tab bar item."))
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: importTarget == .folder ? [.folder] : [.json]
            ) { result in
                switch importTarget {
                case .folder:
                    switch result {
                    case .success(let url): autoBackup.chooseFolder(url)
                    case .failure(let error): autoBackup.folderPickerFailed(error)
                    }
                case .backup:
                    restore.open(result, from: .settings)
                }
            }
        }
    }

    // MARK: - Anggaran, Subkategori, Tentang (D-062)

    private var budgetSection: some View {
        Section {
            ForEach(ExpenseGroup.allCases, id: \.self) { group in
                Button {
                    budgetRoute = GroupBudgetRoute(group: group)
                } label: {
                    BudgetRowLabel(title: Text(group.title), amount: settings.first?.budget(for: group))
                }
                .accessibilityIdentifier("settings.budget.\(group.rawValue)")
            }
        } header: {
            Text(LocalizedStringResource(
                "settings.section.budgets",
                defaultValue: "Anggaran",
                comment: "Pengaturan: header of the budgets section (Kebutuhan and Keinginan). Plural sense in English (Budgets)."
            ))
        } footer: {
            Text(
                "Anggaran bulanan tiap kelompok, tampil di Beranda. Anggaran per subkategori diatur di Kelola subkategori.",
                comment: "Pengaturan: footer of the budgets section. Group budgets show on Home; subcategory budgets are set in Kelola subkategori (D-041)."
            )
        }
    }

    private func groupBudgetSheet(_ group: ExpenseGroup) -> some View {
        let name = String(localized: group.title)
        return BudgetAmountSheet(
            title: Text(
                "Anggaran \(name)",
                comment: "Title of a budget sheet: a group's from Pengaturan, e.g. 'Anggaran Kebutuhan', or one subcategory's from its editor, e.g. 'Anggaran Kopi'. The placeholder is the group or subcategory name."
            ),
            note: Text(
                "Untuk semua pengeluaran \(name) dalam sebulan.",
                comment: "Budget sheet for a group: the note under the amount, e.g. 'Untuk semua pengeluaran Kebutuhan dalam sebulan.' The placeholder is the group name."
            ),
            current: settings.first?.budget(for: group)
        ) { amount in
            try Ledger(context: context, timeZone: .autoupdatingCurrent).setGroupBudget(amount, for: group)
        }
    }

    private var subcategorySection: some View {
        Section {
            NavigationLink {
                SubcategoryListView()
            } label: {
                Label {
                    Text("Kelola subkategori", comment: "Pengaturan: the row that opens subcategory management, and that screen's title.")
                } icon: {
                    Image(systemName: "square.grid.2x2")
                }
            }
            .accessibilityIdentifier("settings.subcategories")
        } header: {
            Text(LocalizedStringResource(
                "settings.section.subcategories",
                defaultValue: "Subkategori",
                comment: "Pengaturan: header of the subcategories section. Plural sense in English (Subcategories)."
            ))
        } footer: {
            Text(
                "Tambah, ubah, urutkan, atau sembunyikan subkategori, dan atur anggarannya.",
                comment: "Pengaturan: footer of the subcategories section, listing what Kelola subkategori does."
            )
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(verbatim: Self.version)
                    .accessibilityIdentifier("settings.version")
            } label: {
                Text("Versi", comment: "Pengaturan: the app version row in the Tentang section.")
            }
            if let onShowIntroduction {
                Button {
                    onShowIntroduction()
                } label: {
                    Label {
                        Text("Lihat pengenalan lagi", comment: "Pengaturan: shows the first-launch introduction (onboarding) again.")
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
                .accessibilityIdentifier("settings.introduction")
            }
        } header: {
            Text("Tentang", comment: "Pengaturan: header of the About section (app version).")
        }
    }

    /// "1.0 (1)": the marketing version and the build number from the bundle.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
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
        } else if let failure = autoBackup.lastFailure {
            failureText(failure)
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
                "Folder ini sudah berisi cadangan, dan cadangan itu tidak akan ditimpa. Pulihkan untuk memakainya. Kalau kamu mulai mencatat dulu, cadangan itu tetap aman dan disimpan dengan nama baru.",
                comment: "Pengaturan: the app has no data yet and the folder already holds a backup. It is never overwritten: restore it, or start logging and it is kept under a new file name."
            )
        } else if autoBackup.waitingForData {
            Text(
                "Belum ada data untuk dicadangkan. Cadangan dibuat setelah kamu mulai mencatat.",
                comment: "Pengaturan: the app has no data yet and the folder has no backup, so nothing is written until the first entry."
            )
        } else if let date = autoBackup.lastSuccess {
            Text(
                "Terakhir dicadangkan \(date.formatted(Date.FormatStyle.gregorian(locale: locale).day().month(.abbreviated).year().hour().minute()))",
                comment: "Pengaturan: when the last automatic backup was written, e.g. '20 Nov 2026 14.05'."
            )
            if let archived = autoBackup.archivedBackupName {
                Text(
                    "Cadangan lama di folder ini disimpan sebagai \(archived).",
                    comment: "Pengaturan: the backup that was already in the folder was kept under this file name, e.g. 'Kemanaya-backup-kept-2026-11-20.json'."
                )
            }
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
                    Text("Pulihkan dari cadangan", comment: "Restores all data from a backup file: Pengaturan's row, the link in Home's empty state on a fresh install, and onboarding's last page.")
                } icon: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .accessibilityIdentifier("settings.restore")
            RestoreStatusText(status: restore.status(for: .settings))
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

/// Which group's budget sheet is open. A wrapper, so the core enum needn't conform to `Identifiable` here.
private struct GroupBudgetRoute: Identifiable {
    let group: ExpenseGroup
    var id: String { group.rawValue }
}

#if DEBUG
#Preview {
    let container = PreviewStore.makeContainer()
    SettingsView()
        .modelContainer(container)
        .environment(AutoBackup(container: container, defaults: nil))
        .environment(RestoreController())
}
#endif
