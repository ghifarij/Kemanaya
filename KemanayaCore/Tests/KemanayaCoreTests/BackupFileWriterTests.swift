import Foundation
@testable import KemanayaCore
import Testing

/// The automatic backup's files (D-019, D-060): `Kemanaya-backup.json`, rotated to `.prev.json` first.
struct BackupFileWriterTests {
    /// A new empty folder in the temporary directory, removed when `body` returns.
    private func withFolder(_ body: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BackupFileWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(folder)
    }

    private func contents(_ folder: URL, _ name: String) -> String? {
        (try? Data(contentsOf: folder.appendingPathComponent(name))).map { String(decoding: $0, as: UTF8.self) }
    }

    @Test func theFirstWriteCreatesOnlyTheBackup() throws {
        try withFolder { folder in
            let outcome = try BackupFileWriter.write(Data("one".utf8), to: folder)
            #expect(outcome == .written)
            #expect(contents(folder, "Kemanaya-backup.json") == "one")
            #expect(contents(folder, "Kemanaya-backup.prev.json") == nil)
        }
    }

    @Test func eachWriteRotatesThePreviousBackup() throws {
        try withFolder { folder in
            try BackupFileWriter.write(Data("one".utf8), to: folder)
            try BackupFileWriter.write(Data("two".utf8), to: folder)
            #expect(contents(folder, "Kemanaya-backup.json") == "two")
            #expect(contents(folder, "Kemanaya-backup.prev.json") == "one")

            try BackupFileWriter.write(Data("three".utf8), to: folder)
            #expect(contents(folder, "Kemanaya-backup.json") == "three")
            #expect(contents(folder, "Kemanaya-backup.prev.json") == "two", "the older .prev is replaced")
            let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
            #expect(names == ["Kemanaya-backup.json", "Kemanaya-backup.prev.json"], "no temporary files are left")
        }
    }

    /// A fresh install never pushes a real backup out (D-060).
    @Test func anExistingBackupCanBeKept() throws {
        try withFolder { folder in
            try BackupFileWriter.write(Data("real".utf8), to: folder)
            try BackupFileWriter.write(Data("older".utf8), to: folder)
            let outcome = try BackupFileWriter.write(Data("empty".utf8), to: folder, overwritingExisting: false)
            #expect(outcome == .keptExisting)
            #expect(contents(folder, "Kemanaya-backup.json") == "older")
            #expect(contents(folder, "Kemanaya-backup.prev.json") == "real")
        }
        try withFolder { folder in
            let outcome = try BackupFileWriter.write(Data("first".utf8), to: folder, overwritingExisting: false)
            #expect(outcome == .written, "nothing to keep")
            #expect(contents(folder, "Kemanaya-backup.json") == "first")
        }
    }

    @Test func aMissingFolderThrows() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)", isDirectory: true)
        #expect(throws: (any Error).self) { try BackupFileWriter.write(Data("x".utf8), to: folder) }
    }

    /// A real backup written and read back through the writer.
    @Test func aWrittenBackupDecodes() throws {
        let document = BackupDocument(
            exportedAt: Fixtures.date(2026, 11, 20),
            appVersion: "1.0",
            subcategories: [],
            transactions: [],
            rollups: [],
            settings: .init(kebutuhanBudget: nil, keinginanBudget: nil, seedVersion: 1)
        )
        try withFolder { folder in
            try BackupFileWriter.write(try document.encoded(), to: folder)
            let data = try Data(contentsOf: folder.appendingPathComponent(BackupFileWriter.fileName))
            let decoded = try BackupDocument.decode(data)
            #expect(decoded == document)
        }
    }
}
