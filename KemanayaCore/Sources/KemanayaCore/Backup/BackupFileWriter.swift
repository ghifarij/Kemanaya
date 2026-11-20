import Foundation

/// Writes the automatic backup into a folder (D-019, D-060): `Kemanaya-backup.json`, with the copy before
/// it kept as `Kemanaya-backup.prev.json`.
///
/// - **Rotation:** the old `Kemanaya-backup.json` replaces `Kemanaya-backup.prev.json`, then the new file
///   is written. If the app dies between the two, the previous backup is still there as `.prev`.
/// - **Archiving:** with `archivingExisting` (``AutoBackupPolicy``: the first write of this install into
///   the folder), an existing `Kemanaya-backup.json` is renamed to `Kemanaya-backup-kept-YYYY-MM-DD.json`
///   instead of rotated, and `.prev` is left alone. A backup the app didn't write is never deleted.
/// - **Atomic:** the new file is written to a temporary file and renamed into place, so a reader never sees
///   half a backup.
/// - **Coordinated:** both files are accessed through one `NSFileCoordinator` write, so iCloud Drive (or
///   another file provider) never syncs a file mid-change.
///
/// Knows nothing of security scope: the caller starts and stops access to the folder around the call.
/// Synchronous and blocking (coordination can wait on a file provider), so call it off the main thread.
public enum BackupFileWriter {
    public static let fileName = "Kemanaya-backup.json"
    public static let previousFileName = "Kemanaya-backup.prev.json"
    /// The one-off copy of the data a restore replaced (``writeBeforeRestore(_:to:)``).
    public static let beforeRestoreFileName = "Kemanaya-backup-before-restore.json"

    /// What a write did.
    public enum Outcome: Equatable, Sendable {
        /// The new backup is in place. `archivedAs` is the `-kept-` name an existing backup was renamed
        /// to, or nil when there was none to archive (or it was rotated to `.prev`).
        case written(archivedAs: String?)
    }

    /// - Parameters:
    ///   - data: the encoded ``BackupDocument``.
    ///   - folder: the backup folder.
    ///   - archivingExisting: rename an existing `Kemanaya-backup.json` to a `-kept-` name instead of
    ///     rotating it (``AutoBackupPolicy/Decision/write(archivingExisting:)``).
    ///   - now: the clock, for the `-kept-` name's date.
    ///   - timeZone: the zone of that date; the device's.
    /// - Throws: the coordination or file error. A failure before the rename leaves the files as they were.
    @discardableResult
    public static func write(
        _ data: Data,
        to folder: URL,
        archivingExisting: Bool = false,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) throws -> Outcome {
        let current = folder.appendingPathComponent(fileName, isDirectory: false)
        // Where an existing file goes: `.prev`, or a free `-kept-` name.
        let destination: URL
        let archiveName: String?
        if archivingExisting {
            let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            let name = keptFileName(on: now, timeZone: timeZone, existing: existing)
            archiveName = name
            destination = folder.appendingPathComponent(name, isDirectory: false)
        } else {
            archiveName = nil
            destination = folder.appendingPathComponent(previousFileName, isDirectory: false)
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<Outcome, any Error> = .success(.written(archivedAs: nil))
        coordinator.coordinate(
            writingItemAt: current,
            options: .forMoving,
            writingItemAt: destination,
            options: .forReplacing,
            error: &coordinationError
        ) { current, destination in
            result = Result {
                let files = FileManager.default
                var archived: String?
                if files.fileExists(atPath: current.path) {
                    if archiveName == nil, files.fileExists(atPath: destination.path) {
                        // Only ever the old `.prev`: a `-kept-` name was picked free.
                        try files.removeItem(at: destination)
                    }
                    try files.moveItem(at: current, to: destination)
                    coordinator.item(at: current, didMoveTo: destination)
                    archived = archiveName
                }
                try data.write(to: current, options: .atomic)
                return .written(archivedAs: archived)
            }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    /// `Kemanaya-backup-kept-YYYY-MM-DD.json` for `date` in `timeZone` (Gregorian), with `-2`, `-3`, …
    /// before the extension when `existing` (the folder's file names) already has that name.
    public static func keptFileName(on date: Date, timeZone: TimeZone, existing: Set<String>) -> String {
        let parts = Calendar.gregorian(in: timeZone).dateComponents([.year, .month, .day], from: date)
        let stem = String(format: "Kemanaya-backup-kept-%04ld-%02ld-%02ld", parts.year!, parts.month!, parts.day!)
        var name = stem + ".json"
        var suffix = 2
        while existing.contains(name) {
            name = "\(stem)-\(suffix).json"
            suffix += 1
        }
        return name
    }

    /// Whether `folder` holds a `Kemanaya-backup.json`, downloaded or still only an iCloud Drive
    /// placeholder (`.Kemanaya-backup.json.icloud`). Pengaturan says it is kept (D-060).
    public static func hasBackup(in folder: URL) -> Bool {
        let files = FileManager.default
        return files.fileExists(atPath: folder.appendingPathComponent(fileName, isDirectory: false).path)
            || files.fileExists(atPath: folder.appendingPathComponent(".\(fileName).icloud", isDirectory: false).path)
    }

    /// Writes `data` (the data a restore is about to replace) as `Kemanaya-backup-before-restore.json`,
    /// replacing any earlier one: a way back from a mistaken restore that the next two automatic writes
    /// can't rotate away. Atomic and coordinated; the other backup files are not touched.
    public static func writeBeforeRestore(_ data: Data, to folder: URL) throws {
        let file = folder.appendingPathComponent(beforeRestoreFileName, isDirectory: false)
        var coordinationError: NSError?
        var result: Result<Void, any Error> = .success(())
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: file, options: .forReplacing, error: &coordinationError) { file in
            result = Result { try data.write(to: file, options: .atomic) }
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }
}
