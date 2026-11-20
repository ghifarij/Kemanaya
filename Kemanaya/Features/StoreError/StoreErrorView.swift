import KemanayaCore
import SwiftUI

/// Shown instead of the app when the data store won't open (D-063, Phase 3 note b). It replaces a crash.
///
/// It says what happened in plain words, says the data was left alone, and says what to try. It never
/// deletes, moves or migrates the store: the next launch tries to open it again as it is. What it can
/// offer to save is ``StoreRescue``'s: the last automatic backup when a folder is set, and a copy of the
/// store files as they are. Si Naya is sleepy here, never alarmed (D-022).
struct StoreErrorView: View {
    let rescue: StoreRescue

    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EmptyStateMascot(mood: .sleepy, size: 120)
                    .frame(maxWidth: .infinity)
                Text("Data tidak bisa dibuka", comment: "Store error screen title: the app could not open its data this time.")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("storeError.title")
                paragraph(Text(
                    "Kemanaya gagal membuka datamu kali ini. Datamu tidak dihapus dan tidak diubah.",
                    comment: "Store error screen: what happened. The data was not deleted or changed."
                ))
                paragraph(Text(
                    "Tutup aplikasinya, lalu buka lagi. Kalau masih begini, jangan hapus aplikasinya, karena datamu tersimpan di dalamnya.",
                    comment: "Store error screen: what to try. Close and reopen the app; if it persists, don't delete the app, because the data is inside it."
                ))
                saveSection
                Text(
                    "Kode: \(rescue.errorCode)",
                    comment: "Store error screen: a short technical code for the failure, e.g. 'Kode: NSCocoaErrorDomain 134110'."
                )
                .font(.footnote.monospaced())
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityIdentifier("storeError.code")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Color(.textPrimary))
        .background(Color(.appBackground).ignoresSafeArea())
    }

    // MARK: - Saving a copy

    @ViewBuilder private var saveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Simpan salinan", comment: "Store error screen: header of the section that offers to save a copy of the data.")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let lastBackup = rescue.lastBackup {
                lastBackupRow(lastBackup)
            }
            if !rescue.storeFiles.isEmpty {
                storeFilesRow
            }
            if rescue.lastBackup == nil, rescue.storeFiles.isEmpty {
                note(Text(
                    "Belum ada cadangan yang bisa disimpan dari sini.",
                    comment: "Store error screen: there is no backup folder and no data file to copy."
                ))
                .accessibilityIdentifier("storeError.nothingToSave")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    private func lastBackupRow(_ backup: StoreRescue.LastBackup) -> some View {
        let export = LastBackupExport(backup: backup)
        return VStack(alignment: .leading, spacing: 6) {
            ShareLink(item: export, preview: SharePreview(export.fileName, image: Image(systemName: "doc"))) {
                actionLabel(
                    Text("Ekspor cadangan terakhir", comment: "Store error screen: shares a copy of the last automatic backup file."),
                    systemImage: "square.and.arrow.up"
                )
            }
            .accessibilityIdentifier("storeError.exportBackup")
            note(lastBackupDescription(backup))
        }
    }

    private func lastBackupDescription(_ backup: StoreRescue.LastBackup) -> Text {
        let folder = backup.folderName ?? "–"
        guard let date = backup.date else {
            return Text(
                "Salinan cadangan otomatis di folder \(folder). Bisa dipulihkan lewat Pulihkan dari cadangan.",
                comment: "Store error screen, under Ekspor cadangan terakhir when the last backup time is unknown. The placeholder is the backup folder's name."
            )
        }
        let when = date.formatted(Date.FormatStyle.gregorian(locale: locale).day().month(.abbreviated).year().hour().minute())
        return Text(
            "Cadangan otomatis dari \(when), di folder \(folder). Bisa dipulihkan lewat Pulihkan dari cadangan.",
            comment: "Store error screen, under Ekspor cadangan terakhir. 1: when it was written, e.g. '20 Nov 2026 14.05'. 2: the backup folder's name."
        )
    }

    private var storeFilesRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShareLink(items: rescue.storeFiles.map(StoreFileCopy.init)) { file in
                SharePreview(file.url.lastPathComponent, image: Image(systemName: "doc"))
            } label: {
                actionLabel(
                    Text("Simpan salinan berkas data", comment: "Store error screen: shares a copy of the raw data files exactly as they are."),
                    systemImage: "doc.on.doc"
                )
            }
            .accessibilityIdentifier("storeError.exportStoreFiles")
            note(Text(
                "Berkas data apa adanya, untuk diperbaiki nanti. Berkas ini bukan cadangan, jadi tidak bisa dipakai untuk Pulihkan dari cadangan.",
                comment: "Store error screen, under Simpan salinan berkas data: the raw files as they are, for a later repair. Not a backup, so Pulihkan dari cadangan can't use them."
            ))
        }
    }

    // MARK: - Pieces

    private func actionLabel(_ text: Text, systemImage: String) -> some View {
        Label {
            text
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(Color(.brand))
        .frame(minHeight: 44, alignment: .leading)
    }

    private func paragraph(_ text: Text) -> some View {
        text
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func note(_ text: Text) -> some View {
        text
            .font(.footnote)
            .foregroundStyle(Color(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
    }
}

#if DEBUG
#Preview("Nothing to save") {
    StoreErrorView(rescue: StoreRescue(lastBackup: nil, storeFiles: [], errorCode: "NSCocoaErrorDomain 134110"))
}

#Preview("With exports") {
    StoreErrorView(rescue: SimulatedStoreFailure.exports.rescue)
}
#endif
