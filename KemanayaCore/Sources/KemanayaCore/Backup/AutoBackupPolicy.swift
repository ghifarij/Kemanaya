/// What the automatic backup (D-019, D-060) does on each run, as plain values so every decision is
/// tested without files, bookmarks or SwiftData. The app keeps one per folder in `UserDefaults`.
///
/// - **Fresh store:** while ``Backup/isFreshInstall(_:)`` is true (only the seed), nothing is written at
///   all. A seed-only backup is worthless, and an existing `Kemanaya-backup.json` in the folder (for
///   example from before a reinstall, maybe not even downloaded from iCloud Drive yet) stays untouched.
/// - **A backup this install didn't write:** the first real write into a folder first renames the
///   `Kemanaya-backup.json` already there to `Kemanaya-backup-kept-YYYY-MM-DD.json`
///   (``BackupFileWriter/keptFileName(on:timeZone:existing:)``) instead of rotating it to `.prev`, so
///   logging a few entries before restoring can never push the real backup out. Only after that first
///   write does the normal `.prev` rotation start.
/// - **During a restore:** a write waits until the restore is done, so it never snapshots a store
///   halfway through being replaced.
///
/// "This install" is what `UserDefaults` remembers: it is wiped when the app is deleted, together with
/// ``hasWrittenToFolder``, so after a reinstall any backup in the folder counts as one to keep.
public struct AutoBackupPolicy: Equatable, Sendable {
    /// What one run does.
    public enum Decision: Equatable, Sendable {
        /// The store only has the seed: write nothing, leave the folder alone.
        case skipFreshStore
        /// A restore is replacing the data: write once it is done.
        case deferUntilRestored
        /// Write the backup. With `archivingExisting`, a `Kemanaya-backup.json` already in the folder is
        /// renamed to a `-kept-` name first instead of rotated.
        case write(archivingExisting: Bool)
    }

    /// True once this install has written a backup into the current folder. Until then any
    /// `Kemanaya-backup.json` there is someone else's (another install's or device's) and is kept.
    public private(set) var hasWrittenToFolder: Bool

    public init(hasWrittenToFolder: Bool = false) {
        self.hasWrittenToFolder = hasWrittenToFolder
    }

    /// The decision for a run now.
    /// - Parameters:
    ///   - isFreshStore: ``Backup/isFreshInstall(_:)``.
    ///   - isRestoring: a restore is under way.
    public func decision(isFreshStore: Bool, isRestoring: Bool) -> Decision {
        if isRestoring { return .deferUntilRestored }
        if isFreshStore { return .skipFreshStore }
        return .write(archivingExisting: !hasWrittenToFolder)
    }

    /// A backup was written into the folder: from now on an existing file is ours and rotates to `.prev`.
    public mutating func recordWrite() {
        hasWrittenToFolder = true
    }

    /// The folder was picked again, changed or forgotten: whatever is in the new one isn't ours yet.
    public mutating func folderChanged() {
        hasWrittenToFolder = false
    }

    /// Whether a restore first saves the current data as `Kemanaya-backup-before-restore.json`
    /// (``BackupFileWriter/writeBeforeRestore(_:to:)``): only with a folder set, and only when there is
    /// more than the seed to lose.
    public static func writesBeforeRestore(hasFolder: Bool, isFreshStore: Bool) -> Bool {
        hasFolder && !isFreshStore
    }
}
