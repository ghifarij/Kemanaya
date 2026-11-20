import Foundation
import KemanayaCore
import OSLog
import SwiftData
import UIKit

/// The automatic backup (D-019, D-060): `Kemanaya-backup.json` in a folder the user picked once, written
/// 5 s after the last saved change and once on launch.
///
/// - **Folder:** remembered as a bookmark in `UserDefaults`, never in the backup, because it only works on
///   the device that made it. A stale bookmark is refreshed on the next write. Access to the folder is
///   started and stopped around each write.
/// - **Trigger:** every `ModelContext.didSave` (the add sheet, edits, deletes, pins, retention, a restore)
///   restarts a 5 s timer; going to the background writes a pending backup at once, inside a background
///   task so iOS doesn't suspend the app mid-write.
/// - **What a run does** is ``AutoBackupPolicy``'s call: a fresh store (only the seed) writes nothing at
///   all, so an existing backup in the folder is never touched before it is restored; the first real
///   write of this install into a folder renames a backup already there to `Kemanaya-backup-kept-…json`
///   instead of rotating it; a run during a restore waits for it. The policy's state is kept in
///   `UserDefaults` with the bookmark, so a relaunch doesn't forget it, and a new folder starts over.
/// - **Before a restore** (``beginRestore()``), the data about to be replaced is written once as
///   `Kemanaya-backup-before-restore.json`, so a mistaken restore can be undone.
/// - **Failures** are logged and kept for Pengaturan to show inline, never as an alert.
/// - **Throwaway stores** (UI tests, unit-test hosts, previews) get no `UserDefaults`: nothing is read or
///   remembered and nothing is ever written, so test data can't overwrite a real backup.
@Observable
final class AutoBackup {
    /// Why the last automatic backup failed.
    nonisolated enum Failure: String, Sendable {
        /// The bookmark no longer resolves (folder moved, deleted or access revoked), or the folder picker
        /// failed: pick it again.
        case folderUnavailable
        /// The folder resolved but the file couldn't be written; the next change tries again.
        case writeFailed
        /// The store couldn't be read or encoded.
        case snapshotFailed
    }

    nonisolated static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Backup")
    /// Quiet time after the last save before writing (D-019).
    static let debounce: Duration = .seconds(5)

    /// The picked folder's name, e.g. "Kemanaya"; nil when automatic backup is off.
    private(set) var folderName: String?
    /// The last backup actually written.
    private(set) var lastSuccess: Date?
    /// The last failure, cleared by the next success.
    private(set) var lastFailure: Failure?
    private(set) var lastFailureAt: Date?
    /// The store is fresh and the folder holds a backup, which is left alone (D-060).
    private(set) var keptExistingBackup = false
    /// The store is fresh and the folder has no backup: nothing is written until there is data.
    private(set) var waitingForData = false
    /// The `-kept-` name a backup this install didn't write was saved under, by the first real write.
    private(set) var archivedBackupName: String?
    private(set) var isWriting = false
    private var bookmark: Data?

    /// Whether a folder is set, i.e. automatic backup is on.
    var hasFolder: Bool { bookmark != nil }

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private var policy = AutoBackupPolicy()
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var writing: Task<Void, Never>?
    @ObservationIgnored private var observer: (any NSObjectProtocol)?
    @ObservationIgnored private var runAgain = false
    @ObservationIgnored private var isRestoring = false
    @ObservationIgnored private var deferredDuringRestore = false

    /// - Parameter defaults: where the folder and status are remembered; nil for a throwaway store.
    init(container: ModelContainer, defaults: UserDefaults?) {
        self.container = container
        self.defaults = defaults
        guard let defaults else { return }
        bookmark = defaults.data(forKey: Keys.bookmark)
        folderName = defaults.string(forKey: Keys.folderName)
        lastSuccess = defaults.object(forKey: Keys.lastSuccess) as? Date
        lastFailure = defaults.string(forKey: Keys.lastFailure).flatMap(Failure.init(rawValue:))
        lastFailureAt = defaults.object(forKey: Keys.lastFailureAt) as? Date
        keptExistingBackup = defaults.bool(forKey: Keys.keptExisting)
        archivedBackupName = defaults.string(forKey: Keys.archivedName)
        policy = AutoBackupPolicy(hasWrittenToFolder: defaults.bool(forKey: Keys.hasWrittenToFolder))
    }

    /// Starts listening for saves and writes the launch backup. Does nothing for a throwaway store.
    /// The service lives as long as the app, so the observer is never removed.
    func start() {
        guard defaults != nil, observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleBackup() }
        }
        if hasFolder {
            Task { await backUpNow() }
        }
    }

    // MARK: - Folder

    /// Remembers `url` (from the folder picker) as the backup folder and writes a backup into it.
    func chooseFolder(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            // iOS has no `.withSecurityScope`: a bookmark made while the picked URL is being accessed
            // carries its scope implicitly.
            bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            folderName = url.lastPathComponent
            resetFolderState()
            Self.logger.info("Backup folder chosen")
        } catch {
            Self.logger.error("Could not bookmark the backup folder: \(error.localizedDescription, privacy: .public)")
            record(.folderUnavailable)
        }
        persist()
        if hasFolder {
            Task { await backUpNow() }
        }
    }

    /// The folder picker failed: logged, and shown as "pick the folder again".
    func folderPickerFailed(_ error: any Error) {
        Self.logger.error("Backup folder picker failed: \(error.localizedDescription, privacy: .public)")
        record(.folderUnavailable)
    }

    /// Turns automatic backup off. The files already in the folder stay there.
    func forgetFolder() {
        pending?.cancel()
        pending = nil
        bookmark = nil
        folderName = nil
        resetFolderState()
        persist()
        Self.logger.info("Backup folder forgotten")
    }

    /// Everything that belongs to the old folder: a new one starts with its backup kept (``AutoBackupPolicy``).
    private func resetFolderState() {
        lastSuccess = nil
        keptExistingBackup = false
        waitingForData = false
        archivedBackupName = nil
        policy.folderChanged()
        clearFailure()
    }

    // MARK: - Writing

    /// Restarts the 5 s timer after a save.
    private func scheduleBackup() {
        guard hasFolder else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled, let self else { return }
            self.pending = nil
            await self.backUpNow()
        }
    }

    /// Writes a pending backup now, or finishes the one being written, when the app goes to the
    /// background. Runs inside a background task, so iOS gives the write time to finish; the task ends
    /// when the write is done or when iOS says time is up, whichever comes first.
    func flush() {
        let hadPending = pending != nil
        pending?.cancel()
        pending = nil
        guard hadPending || writing != nil else { return }
        let activity = BackgroundActivity(name: "Kemanaya backup")
        Task {
            if hadPending {
                await backUpNow()
            } else {
                await writing?.value
            }
            activity.end()
        }
    }

    /// Writes a backup now ("Cadangkan sekarang", launch, after the timer). A request while one is being
    /// written runs once more afterwards, so the last change is always in the file; it returns when that
    /// write is done.
    func backUpNow() async {
        guard hasFolder, defaults != nil else { return }
        if let writing {
            runAgain = true
            await writing.value
            return
        }
        isWriting = true
        let task = Task {
            repeat {
                runAgain = false
                await writeOnce()
            } while runAgain && hasFolder
        }
        writing = task
        await task.value
        writing = nil
        isWriting = false
    }

    private func writeOnce() async {
        guard let bookmark else { return }
        let context = container.mainContext
        let isFresh: Bool
        do {
            isFresh = try Backup.isFreshInstall(context)
        } catch {
            Self.logger.error("Backup could not read the store: \(error.localizedDescription, privacy: .public)")
            record(.snapshotFailed)
            return
        }

        switch policy.decision(isFreshStore: isFresh, isRestoring: isRestoring) {
        case .deferUntilRestored:
            deferredDuringRestore = true
            Self.logger.info("Backup deferred until the restore is done")

        case .skipFreshStore:
            // Nothing is written; only look whether there is a backup to keep, for Pengaturan.
            let report = await Self.inFolder(bookmark) { BackupFileWriter.hasBackup(in: $0) }
            guard self.bookmark == bookmark else { return }
            apply(report.refreshedBookmark)
            switch report.outcome {
            case .success(let hasBackup):
                keptExistingBackup = hasBackup
                waitingForData = !hasBackup
                clearFailure()
                Self.logger.info("Fresh store: nothing written (backup in folder: \(hasBackup))")
            case .failure(let box):
                record(box.failure)
            }
            persist()

        case .write(let archivingExisting):
            let document: BackupDocument
            do {
                document = try Backup.snapshot(of: context, exportedAt: .now, appVersion: Self.appVersion)
            } catch {
                Self.logger.error("Backup snapshot failed: \(error.localizedDescription, privacy: .public)")
                record(.snapshotFailed)
                return
            }
            let report = await Self.inFolder(bookmark) { folder in
                let data: Data
                do {
                    data = try document.encoded()
                } catch {
                    throw EncodingFailed(underlying: error)
                }
                return try BackupFileWriter.write(data, to: folder, archivingExisting: archivingExisting)
            }
            // The folder was changed or forgotten while writing: that result is about the old folder.
            guard self.bookmark == bookmark else { return }
            apply(report.refreshedBookmark)
            switch report.outcome {
            case .success(.written(let archivedAs)):
                lastSuccess = .now
                keptExistingBackup = false
                waitingForData = false
                policy.recordWrite()
                if let archivedAs {
                    archivedBackupName = archivedAs
                    Self.logger.info("The backup already in the folder was kept as \(archivedAs, privacy: .public)")
                }
                clearFailure()
                Self.logger.info("Backup written (\(document.transactions.count) transactions)")
            case .failure(let box):
                record(box.failure)
            }
            persist()
        }
    }

    // MARK: - Restore

    /// Called by the restore flow right before it replaces the data. Holds automatic writes until
    /// ``endRestore()`` and, when a folder is set and the store has more than the seed
    /// (``AutoBackupPolicy/writesBeforeRestore(hasFolder:isFreshStore:)``), writes the current data as
    /// `Kemanaya-backup-before-restore.json`. A failure there is logged and the restore goes ahead.
    func beginRestore() async {
        isRestoring = true
        guard let bookmark, defaults != nil else { return }
        let context = container.mainContext
        let isFresh = (try? Backup.isFreshInstall(context)) ?? false
        guard AutoBackupPolicy.writesBeforeRestore(hasFolder: true, isFreshStore: isFresh) else { return }
        let document: BackupDocument
        do {
            document = try Backup.snapshot(of: context, exportedAt: .now, appVersion: Self.appVersion)
        } catch {
            Self.logger.error("Before-restore snapshot failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        let report = await Self.inFolder(bookmark) { folder in
            try BackupFileWriter.writeBeforeRestore(try document.encoded(), to: folder)
        }
        if self.bookmark == bookmark { apply(report.refreshedBookmark) }
        switch report.outcome {
        case .success:
            Self.logger.info("Wrote the before-restore copy (\(document.transactions.count) transactions)")
        case .failure(let box):
            Self.logger.error("Before-restore copy failed (\(box.failure.rawValue, privacy: .public)); restoring anyway")
        }
    }

    /// The restore is done (or failed): a write held back meanwhile is scheduled.
    func endRestore() {
        isRestoring = false
        if deferredDuringRestore {
            deferredDuringRestore = false
            scheduleBackup()
        }
    }

    // MARK: - Off the main actor

    /// What work in the folder, off the main actor, returned.
    private nonisolated struct FolderReport<Value: Sendable>: Sendable {
        var outcome: Result<Value, FailureBox>
        /// A new bookmark when the stored one was stale.
        var refreshedBookmark: Data?
    }

    /// `Failure` as an `Error`, for `Result`.
    private nonisolated struct FailureBox: Error {
        let failure: Failure
    }

    /// Encoding the backup failed: a snapshot problem, not a folder one.
    private nonisolated struct EncodingFailed: Error {
        let underlying: any Error
    }

    /// Resolves the folder, starts access, runs `body` in it and stops access, off the main actor:
    /// coordination can wait on iCloud Drive.
    private nonisolated static func inFolder<Value: Sendable>(
        _ bookmark: Data,
        _ body: @escaping @Sendable (URL) throws -> Value
    ) async -> FolderReport<Value> {
        await Task.detached(priority: .utility) {
            var isStale = false
            let folder: URL
            do {
                folder = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            } catch {
                logger.error("Backup folder bookmark did not resolve: \(error.localizedDescription, privacy: .public)")
                return FolderReport(outcome: .failure(FailureBox(failure: .folderUnavailable)))
            }
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            let refreshed = isStale
                ? try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                : nil
            do {
                return FolderReport(outcome: .success(try body(folder)), refreshedBookmark: refreshed)
            } catch let error as EncodingFailed {
                logger.error("Backup encoding failed: \(error.underlying.localizedDescription, privacy: .public)")
                return FolderReport(outcome: .failure(FailureBox(failure: .snapshotFailed)), refreshedBookmark: refreshed)
            } catch {
                logger.error("Backup folder write failed (access started: \(accessing)): \(error.localizedDescription, privacy: .public)")
                // Without access the folder is as good as gone: ask for it again.
                let failure: Failure = accessing ? .writeFailed : .folderUnavailable
                return FolderReport(outcome: .failure(FailureBox(failure: failure)), refreshedBookmark: refreshed)
            }
        }.value
    }

    private func apply(_ refreshedBookmark: Data?) {
        if let refreshedBookmark { bookmark = refreshedBookmark }
    }

    private func record(_ failure: Failure) {
        lastFailure = failure
        lastFailureAt = .now
        persist()
    }

    private func clearFailure() {
        lastFailure = nil
        lastFailureAt = nil
    }

    // MARK: - Persistence

    /// The automatic backup folder remembered in `defaults`, read without a store or an instance: for the
    /// screen shown when the store won't open (D-063), which can still offer the last backup. Nil when
    /// automatic backup is off.
    static func savedFolder(in defaults: UserDefaults) -> StoreRescue.LastBackup? {
        guard let bookmark = defaults.data(forKey: Keys.bookmark) else { return nil }
        return StoreRescue.LastBackup(
            bookmark: bookmark,
            folderName: defaults.string(forKey: Keys.folderName),
            date: defaults.object(forKey: Keys.lastSuccess) as? Date
        )
    }

    private enum Keys {
        static let bookmark = "backup.folderBookmark"
        static let folderName = "backup.folderName"
        static let lastSuccess = "backup.lastSuccess"
        static let lastFailure = "backup.lastFailure"
        static let lastFailureAt = "backup.lastFailureAt"
        static let keptExisting = "backup.keptExisting"
        static let archivedName = "backup.archivedName"
        /// ``AutoBackupPolicy/hasWrittenToFolder``: wiped with the app, so a reinstall keeps what's there.
        static let hasWrittenToFolder = "backup.hasWrittenToFolder"
    }

    private func persist() {
        guard let defaults else { return }
        defaults.set(bookmark, forKey: Keys.bookmark)
        defaults.set(folderName, forKey: Keys.folderName)
        defaults.set(lastSuccess, forKey: Keys.lastSuccess)
        defaults.set(lastFailure?.rawValue, forKey: Keys.lastFailure)
        defaults.set(lastFailureAt, forKey: Keys.lastFailureAt)
        defaults.set(keptExistingBackup, forKey: Keys.keptExisting)
        defaults.set(archivedBackupName, forKey: Keys.archivedName)
        defaults.set(policy.hasWrittenToFolder, forKey: Keys.hasWrittenToFolder)
    }

    /// The app's marketing version, written into the backup.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

/// A UIKit background task around work that must finish when the app leaves the foreground. ``end()``
/// is safe to call more than once; iOS's expiry handler calls it too, so the task always ends.
final class BackgroundActivity {
    private var identifier = UIBackgroundTaskIdentifier.invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated {
                AutoBackup.logger.notice("Background time ran out before the backup finished")
                self?.end()
            }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
