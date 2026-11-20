import CoreTransferable
import Foundation
import KemanayaCore
import OSLog
import UniformTypeIdentifiers

/// What the "store won't open" screen (D-063) can offer to save, worked out at launch without the store.
///
/// A JSON backup (``BackupExport``) needs the open store, so it can't be made here. Two honest things can:
/// - **The last automatic backup**, when a folder is set (D-019): a copy of the `Kemanaya-backup.json`
///   already in that folder, the same file "Pulihkan dari cadangan" reads.
/// - **The store files exactly as they are** (the database and its `-wal` and `-shm`): not a backup the
///   app can restore, but everything needed to repair it later.
///
/// Both are read and copied into the temporary directory before sharing. Nothing here ever writes,
/// moves, deletes or migrates the store.
nonisolated struct StoreRescue: Sendable {
    /// The automatic backup folder from `UserDefaults` (``AutoBackup/savedFolder(in:)``).
    struct LastBackup: Sendable {
        let bookmark: Data
        let folderName: String?
        /// When this install last wrote it; nil if it never did (the file may still be there).
        let date: Date?
    }

    let lastBackup: LastBackup?
    /// The existing store files, database first; empty when there are none (``StoreFiles/existing(of:)``).
    let storeFiles: [URL]
    /// A short technical reference for the failure, e.g. "NSCocoaErrorDomain 134110".
    let errorCode: String

    static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Store")

    /// What the real store's failure leaves to save.
    /// - Parameter defaults: nil for a throwaway store, which has no folder and no files.
    @MainActor
    static func current(after error: any Error, defaults: UserDefaults?) -> StoreRescue {
        StoreRescue(
            lastBackup: defaults.flatMap { AutoBackup.savedFolder(in: $0) },
            storeFiles: defaults == nil ? [] : StoreFiles.existing(of: StoreFiles.defaultStoreURL),
            errorCode: code(of: error)
        )
    }

    /// "Domain code", short enough to read out or copy into a bug note.
    static func code(of error: any Error) -> String {
        let error = error as NSError
        return "\(error.domain) \(error.code)"
    }
}

/// "Ekspor cadangan terakhir": a copy of the last automatic backup through the share sheet, named by
/// its date like ``BackupExport`` (`Kemanaya-backup-YYYY-MM-DD.json`), so saving it next to the folder's
/// own file never replaces that one. Read lazily, coordinated (an iCloud Drive file is downloaded first).
nonisolated struct LastBackupExport: Transferable, Sendable {
    let backup: StoreRescue.LastBackup

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            SentTransferredFile(try await export.makeFile())
        }
    }

    var fileName: String {
        BackupExport.fileName(now: backup.date ?? .now)
    }

    private func makeFile() async throws -> URL {
        let bookmark = backup.bookmark
        let name = fileName
        return try await Task.detached(priority: .userInitiated) {
            do {
                var isStale = false
                let folder = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                let accessing = folder.startAccessingSecurityScopedResource()
                defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
                let file = folder.appendingPathComponent(BackupFileWriter.fileName, isDirectory: false)
                var coordinationError: NSError?
                var data: Result<Data, any Error> = .failure(CocoaError(.fileReadUnknown))
                NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: file, options: [], error: &coordinationError) { url in
                    data = Result { try Data(contentsOf: url) }
                }
                if let coordinationError { throw coordinationError }
                return try ExportFiles.write(try data.get(), named: name)
            } catch {
                StoreRescue.logger.error("Last backup export failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }.value
    }
}

/// One store file for "Simpan salinan berkas data": copied as is into the temporary directory, then shared
/// under its own name, so the three files can be put back side by side.
nonisolated struct StoreFileCopy: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { file in
            SentTransferredFile(try file.makeCopy())
        }
    }

    private func makeCopy() throws -> URL {
        do {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("StoreCopy-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let copy = folder.appendingPathComponent(url.lastPathComponent, isDirectory: false)
            try FileManager.default.copyItem(at: url, to: copy)
            return copy
        } catch {
            StoreRescue.logger.error("Store file copy failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

#if DEBUG
/// `-simulateStoreError plain | exports`: open on the error screen without touching any store, for UI
/// tests, screenshots and previews. `plain` has nothing to save; `exports` has a sample backup folder and
/// a sample store file in the temporary directory, so both buttons show and work.
/// Debug builds only. `UserDefaults` reads `-key value` launch arguments, as `-debugSample` does.
enum SimulatedStoreFailure: String {
    case plain, exports

    static var fromLaunchArguments: SimulatedStoreFailure? {
        UserDefaults.standard.string(forKey: "simulateStoreError").flatMap(SimulatedStoreFailure.init(rawValue:))
    }

    struct Failure: Error {}

    var rescue: StoreRescue {
        let code = "SimulatedStoreFailure 1"
        guard self == .exports else { return StoreRescue(lastBackup: nil, storeFiles: [], errorCode: code) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SimulatedStoreError", isDirectory: true)
        let folder = root.appendingPathComponent("Kemanaya", isDirectory: true)
        let store = root.appendingPathComponent("default.store", isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(#"{"simulated":true}"#.utf8).write(to: folder.appendingPathComponent(BackupFileWriter.fileName), options: .atomic)
            try Data("simulated".utf8).write(to: store, options: .atomic)
            let bookmark = try folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            return StoreRescue(
                lastBackup: StoreRescue.LastBackup(bookmark: bookmark, folderName: "Kemanaya", date: .now.addingTimeInterval(-2 * 3_600)),
                storeFiles: [store],
                errorCode: code
            )
        } catch {
            return StoreRescue(lastBackup: nil, storeFiles: [], errorCode: code)
        }
    }
}
#endif
