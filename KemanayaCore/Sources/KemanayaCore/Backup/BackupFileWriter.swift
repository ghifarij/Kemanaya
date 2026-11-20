import Foundation

/// Writes the automatic backup into a folder (D-019, D-060): `Kemanaya-backup.json`, with the copy before
/// it kept as `Kemanaya-backup.prev.json`.
///
/// - **Rotation:** the old `Kemanaya-backup.json` replaces `Kemanaya-backup.prev.json`, then the new file
///   is written. If the app dies between the two, the previous backup is still there as `.prev`.
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

    /// What a write did.
    public enum Outcome: Equatable, Sendable {
        /// The new backup is in place; any old one is now `.prev`.
        case written
        /// `overwritingExisting` was false and a backup was already there: nothing changed.
        case keptExisting
    }

    /// - Parameters:
    ///   - data: the encoded ``BackupDocument``.
    ///   - folder: the backup folder.
    ///   - overwritingExisting: false to leave an existing backup alone, e.g. while the store is fresh, so
    ///     an empty new install never pushes a real backup out (D-060).
    /// - Throws: the coordination or file error. A failure before the rename leaves both files as they were.
    @discardableResult
    public static func write(_ data: Data, to folder: URL, overwritingExisting: Bool = true) throws -> Outcome {
        let current = folder.appendingPathComponent(fileName, isDirectory: false)
        let previous = folder.appendingPathComponent(previousFileName, isDirectory: false)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<Outcome, any Error> = .success(.keptExisting)
        coordinator.coordinate(
            writingItemAt: current,
            options: .forMoving,
            writingItemAt: previous,
            options: .forReplacing,
            error: &coordinationError
        ) { current, previous in
            result = Result {
                let files = FileManager.default
                if files.fileExists(atPath: current.path) {
                    guard overwritingExisting else { return .keptExisting }
                    if files.fileExists(atPath: previous.path) {
                        try files.removeItem(at: previous)
                    }
                    try files.moveItem(at: current, to: previous)
                    coordinator.item(at: current, didMoveTo: previous)
                }
                try data.write(to: current, options: .atomic)
                return .written
            }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }
}
