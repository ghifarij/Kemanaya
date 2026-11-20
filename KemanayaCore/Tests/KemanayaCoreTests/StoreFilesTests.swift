import Foundation
import KemanayaCore
import Testing

struct StoreFilesTests {
    @Test func filesAreTheDatabaseAndItsCompanions() {
        let url = URL(filePath: "/tmp/Library/Application Support/default.store")
        #expect(StoreFiles.files(of: url).map(\.lastPathComponent) == ["default.store", "default.store-wal", "default.store-shm"])
        #expect(Set(StoreFiles.files(of: url).map { $0.deletingLastPathComponent().path }) == [url.deletingLastPathComponent().path])
    }

    @Test func defaultStoreIsOnDiskInApplicationSupport() {
        let url = StoreFiles.defaultStoreURL
        #expect(url.pathExtension == "store")
        #expect(url.path.contains("Application Support"))
    }

    @Test func existingListsOnlyFilesThatExist() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "StoreFilesTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = folder.appending(path: "test.store")

        #expect(StoreFiles.existing(of: store).isEmpty, "no database, nothing to copy")

        // Companions without a database are no store.
        try Data("wal".utf8).write(to: folder.appending(path: "test.store-wal"))
        #expect(StoreFiles.existing(of: store).isEmpty)

        try Data("db".utf8).write(to: store)
        #expect(StoreFiles.existing(of: store).map(\.lastPathComponent) == ["test.store", "test.store-wal"])
    }
}
