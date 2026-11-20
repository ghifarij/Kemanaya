import Foundation
@testable import KemanayaCore
import Testing

/// The automatic backup's files (D-019, D-060): `Kemanaya-backup.json`, rotated to `.prev.json` first, a
/// backup this install didn't write archived to a `-kept-` name, and the one-off before-restore copy.
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

    private func names(_ folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    @Test func theFirstWriteCreatesOnlyTheBackup() throws {
        try withFolder { folder in
            let outcome = try BackupFileWriter.write(Data("one".utf8), to: folder)
            #expect(outcome == .written(archivedAs: nil))
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
            #expect(try names(folder) == ["Kemanaya-backup.json", "Kemanaya-backup.prev.json"], "no temporary files are left")
        }
    }

    /// The first write of an install into a folder that already has a backup (e.g. after a reinstall)
    /// renames that backup instead of rotating it, so two quick writes can never delete it (D-060).
    @Test func aBackupThisInstallDidNotWriteIsArchived() throws {
        let now = Fixtures.date(2026, 11, 20, 9)
        try withFolder { folder in
            try BackupFileWriter.write(Data("older".utf8), to: folder)
            try BackupFileWriter.write(Data("real".utf8), to: folder)

            let outcome = try BackupFileWriter.write(Data("new 1".utf8), to: folder, archivingExisting: true, now: now, timeZone: Fixtures.jakarta)
            #expect(outcome == .written(archivedAs: "Kemanaya-backup-kept-2026-11-20.json"))
            #expect(contents(folder, "Kemanaya-backup-kept-2026-11-20.json") == "real")
            #expect(contents(folder, "Kemanaya-backup.json") == "new 1")
            #expect(contents(folder, "Kemanaya-backup.prev.json") == "older", ".prev is not touched")

            // From then on the normal rotation; the kept file stays whatever happens.
            try BackupFileWriter.write(Data("new 2".utf8), to: folder)
            try BackupFileWriter.write(Data("new 3".utf8), to: folder)
            #expect(contents(folder, "Kemanaya-backup.json") == "new 3")
            #expect(contents(folder, "Kemanaya-backup.prev.json") == "new 2")
            #expect(contents(folder, "Kemanaya-backup-kept-2026-11-20.json") == "real")
        }
    }

    @Test func archivingNeverOverwritesAnEarlierKeptFile() throws {
        let now = Fixtures.date(2026, 11, 20, 9)
        try withFolder { folder in
            try BackupFileWriter.write(Data("a".utf8), to: folder)
            try BackupFileWriter.write(Data("b".utf8), to: folder, archivingExisting: true, now: now, timeZone: Fixtures.jakarta)
            let outcome = try BackupFileWriter.write(Data("c".utf8), to: folder, archivingExisting: true, now: now, timeZone: Fixtures.jakarta)
            #expect(outcome == .written(archivedAs: "Kemanaya-backup-kept-2026-11-20-2.json"))
            #expect(contents(folder, "Kemanaya-backup-kept-2026-11-20.json") == "a")
            #expect(contents(folder, "Kemanaya-backup-kept-2026-11-20-2.json") == "b")
            #expect(contents(folder, "Kemanaya-backup.json") == "c")
        }
    }

    @Test func archivingWithNothingThereJustWrites() throws {
        try withFolder { folder in
            let outcome = try BackupFileWriter.write(Data("first".utf8), to: folder, archivingExisting: true)
            #expect(outcome == .written(archivedAs: nil))
            #expect(try names(folder) == ["Kemanaya-backup.json"])
        }
    }

    @Test func keptNamesUseTheLocalDateAndAFreeSuffix() {
        // 23:30 on 20 November in Los Angeles is already 21 November in Jakarta.
        let date = Fixtures.date(2026, 11, 20, 23, 30, in: Fixtures.losAngeles)
        #expect(BackupFileWriter.keptFileName(on: date, timeZone: Fixtures.losAngeles, existing: []) == "Kemanaya-backup-kept-2026-11-20.json")
        #expect(BackupFileWriter.keptFileName(on: date, timeZone: Fixtures.jakarta, existing: []) == "Kemanaya-backup-kept-2026-11-21.json")
        let taken: Set = ["Kemanaya-backup-kept-2026-11-20.json", "Kemanaya-backup-kept-2026-11-20-2.json"]
        #expect(BackupFileWriter.keptFileName(on: date, timeZone: Fixtures.losAngeles, existing: taken) == "Kemanaya-backup-kept-2026-11-20-3.json")
    }

    @Test func hasBackupSeesTheFileOrItsICloudPlaceholder() throws {
        try withFolder { folder in
            #expect(!BackupFileWriter.hasBackup(in: folder))
            try Data().write(to: folder.appendingPathComponent(".Kemanaya-backup.json.icloud"))
            #expect(BackupFileWriter.hasBackup(in: folder), "not downloaded yet")
        }
        try withFolder { folder in
            try BackupFileWriter.write(Data("x".utf8), to: folder)
            #expect(BackupFileWriter.hasBackup(in: folder))
        }
    }

    /// A one-off copy before a restore: replaced by the next one, and the backup files are not touched.
    @Test func theBeforeRestoreCopyIsItsOwnFile() throws {
        try withFolder { folder in
            try BackupFileWriter.write(Data("one".utf8), to: folder)
            try BackupFileWriter.write(Data("two".utf8), to: folder)
            try BackupFileWriter.writeBeforeRestore(Data("mine 1".utf8), to: folder)
            try BackupFileWriter.writeBeforeRestore(Data("mine 2".utf8), to: folder)
            #expect(contents(folder, "Kemanaya-backup-before-restore.json") == "mine 2", "the earlier one is replaced")
            #expect(contents(folder, "Kemanaya-backup.json") == "two")
            #expect(contents(folder, "Kemanaya-backup.prev.json") == "one")
            #expect(try names(folder) == ["Kemanaya-backup-before-restore.json", "Kemanaya-backup.json", "Kemanaya-backup.prev.json"])
        }
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString)", isDirectory: true)
        #expect(throws: (any Error).self) { try BackupFileWriter.writeBeforeRestore(Data("x".utf8), to: missing) }
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
