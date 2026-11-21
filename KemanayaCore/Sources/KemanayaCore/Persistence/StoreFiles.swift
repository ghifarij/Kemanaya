import Foundation
import SwiftData

/// The files that make up the on-disk store: the SQLite database and its `-wal` and `-shm` companions.
///
/// Used by the "store won't open" screen (D-063) to offer a copy of the files exactly as they are. They
/// are only ever read and copied, never moved, deleted or migrated.
public enum StoreFiles {
    /// Where ``KemanayaStore/makeContainer(inMemory:)`` keeps the real store. Computed without opening it.
    public static var defaultStoreURL: URL {
        ModelConfiguration(schema: KemanayaStore.schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none).url
    }

    /// The database and its companions, in that order, whether or not they exist.
    public static func files(of storeURL: URL) -> [URL] {
        let folder = storeURL.deletingLastPathComponent()
        let name = storeURL.lastPathComponent
        return [name, "\(name)-wal", "\(name)-shm"].map { folder.appendingPathComponent($0, isDirectory: false) }
    }

    /// The files of ``files(of:)`` that exist. Empty when there is no database file: companions on
    /// their own are no store.
    public static func existing(of storeURL: URL, fileManager: FileManager = .default) -> [URL] {
        guard fileManager.fileExists(atPath: storeURL.path) else { return [] }
        return files(of: storeURL).filter { fileManager.fileExists(atPath: $0.path) }
    }
}
