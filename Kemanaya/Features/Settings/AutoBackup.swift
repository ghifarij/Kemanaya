import Foundation
import KemanayaCore
import OSLog
import SwiftData

/// The automatic backup (D-019, D-060): `Kemanaya-backup.json` in a folder the user picked once, written
/// 5 s after the last saved change and once on launch.
///
/// - **Folder:** remembered as a bookmark in `UserDefaults`, never in the backup, because it only works on
///   the device that made it. A stale bookmark is refreshed on the next write. Access to the folder is
///   started and stopped around each write.
/// - **Trigger:** every `ModelContext.didSave` (the add sheet, edits, deletes, pins, retention, a restore)
///   restarts a 5 s timer; going to the background writes a pending backup at once.
/// - **Fresh install:** while the store has no transactions and no rollups (``Backup/isFreshInstall(_:)``),
///   an existing backup in the folder is left alone, so a new install never pushes a real backup out
///   before it is restored.
/// - **Failures** are logged and kept for Pengaturan to show inline, never as an alert.
/// - **Throwaway stores** (UI tests, unit-test hosts, previews) get no `UserDefaults`: nothing is read or
///   remembered and nothing is ever written, so test data can't overwrite a real backup.
@Observable
final class AutoBackup {
    /// Why the last automatic backup failed.
    nonisolated enum Failure: String, Sendable {
        /// The bookmark no longer resolves (folder moved, deleted or access revoked): pick it again.
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
    /// The last run left an existing backup in the folder alone, because the store is fresh.
    private(set) var keptExistingBackup = false
    private(set) var isWriting = false
    private var bookmark: Data?

    /// Whether a folder is set, i.e. automatic backup is on.
    var hasFolder: Bool { bookmark != nil }

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var observer: (any NSObjectProtocol)?
    @ObservationIgnored private var runAgain = false

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
            lastSuccess = nil
            keptExistingBackup = false
            clearFailure()
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

    /// Turns automatic backup off. The files already in the folder stay there.
    func forgetFolder() {
        pending?.cancel()
        pending = nil
        bookmark = nil
        folderName = nil
        lastSuccess = nil
        keptExistingBackup = false
        clearFailure()
        persist()
        Self.logger.info("Backup folder forgotten")
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

    /// Writes a pending backup now, e.g. when the app goes to the background.
    func flush() {
        guard let task = pending else { return }
        task.cancel()
        pending = nil
        Task { await backUpNow() }
    }

    /// Writes a backup now ("Cadangkan sekarang", launch, after the timer). A request while one is being
    /// written runs once more afterwards, so the last change is always in the file.
    func backUpNow() async {
        guard hasFolder, defaults != nil else { return }
        guard !isWriting else {
            runAgain = true
            return
        }
        isWriting = true
        repeat {
            runAgain = false
            await writeOnce()
        } while runAgain && hasFolder
        isWriting = false
    }

    private func writeOnce() async {
        guard let bookmark else { return }
        let document: BackupDocument
        let isFresh: Bool
        do {
            let context = container.mainContext
            document = try Backup.snapshot(of: context, exportedAt: .now, appVersion: Self.appVersion)
            isFresh = try Backup.isFreshInstall(context)
        } catch {
            Self.logger.error("Backup snapshot failed: \(error.localizedDescription, privacy: .public)")
            record(.snapshotFailed)
            return
        }

        let report = await Self.write(document, bookmark: bookmark, overwritingExisting: !isFresh)

        // The folder was changed or forgotten while writing: that result is about the old folder.
        guard self.bookmark == bookmark else { return }
        if let refreshed = report.refreshedBookmark {
            self.bookmark = refreshed
        }
        switch report.outcome {
        case .success(.written):
            lastSuccess = .now
            keptExistingBackup = false
            clearFailure()
            Self.logger.info("Backup written (\(document.transactions.count) transactions)")
        case .success(.keptExisting):
            keptExistingBackup = true
            clearFailure()
            Self.logger.info("Fresh install: the existing backup was kept")
        case .failure(let box):
            record(box.failure)
        }
        persist()
    }

    /// What a write off the main actor did.
    private nonisolated struct WriteReport: Sendable {
        var outcome: Result<BackupFileWriter.Outcome, FailureBox>
        /// A new bookmark when the stored one was stale.
        var refreshedBookmark: Data?
    }

    /// `Failure` as an `Error`, for `Result`.
    private nonisolated struct FailureBox: Error {
        let failure: Failure
    }

    /// Encodes, resolves the folder and writes, off the main actor: coordination can wait on iCloud Drive.
    private nonisolated static func write(_ document: BackupDocument, bookmark: Data, overwritingExisting: Bool) async -> WriteReport {
        await Task.detached(priority: .utility) {
            let data: Data
            do {
                data = try document.encoded()
            } catch {
                logger.error("Backup encoding failed: \(error.localizedDescription, privacy: .public)")
                return WriteReport(outcome: .failure(FailureBox(failure: .snapshotFailed)))
            }
            var isStale = false
            let folder: URL
            do {
                folder = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            } catch {
                logger.error("Backup folder bookmark did not resolve: \(error.localizedDescription, privacy: .public)")
                return WriteReport(outcome: .failure(FailureBox(failure: .folderUnavailable)))
            }
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            let refreshed = isStale
                ? try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                : nil
            do {
                let outcome = try BackupFileWriter.write(data, to: folder, overwritingExisting: overwritingExisting)
                return WriteReport(outcome: .success(outcome), refreshedBookmark: refreshed)
            } catch {
                logger.error("Backup write failed (access started: \(accessing)): \(error.localizedDescription, privacy: .public)")
                // Without access the folder is as good as gone: ask for it again.
                let failure: Failure = accessing ? .writeFailed : .folderUnavailable
                return WriteReport(outcome: .failure(FailureBox(failure: failure)), refreshedBookmark: refreshed)
            }
        }.value
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

    private enum Keys {
        static let bookmark = "backup.folderBookmark"
        static let folderName = "backup.folderName"
        static let lastSuccess = "backup.lastSuccess"
        static let lastFailure = "backup.lastFailure"
        static let lastFailureAt = "backup.lastFailureAt"
        static let keptExisting = "backup.keptExisting"
    }

    private func persist() {
        guard let defaults else { return }
        defaults.set(bookmark, forKey: Keys.bookmark)
        defaults.set(folderName, forKey: Keys.folderName)
        defaults.set(lastSuccess, forKey: Keys.lastSuccess)
        defaults.set(lastFailure?.rawValue, forKey: Keys.lastFailure)
        defaults.set(lastFailureAt, forKey: Keys.lastFailureAt)
        defaults.set(keptExistingBackup, forKey: Keys.keptExisting)
    }

    /// The app's marketing version, written into the backup.
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
