import Foundation
@testable import KemanayaCore
import SwiftData
import Testing

/// The JSON backup and restore (D-019, D-060): exact round trip, stable bytes, refused files change
/// nothing, restore replaces everything in one save, then retention can roll up what it brought back.
struct BackupTests {
    /// 20 Nov 2026, so the raw window starts on 1 Nov 2025 (Jakarta).
    private let now = Fixtures.date(2026, 11, 20)
    private let exportedAt = Fixtures.date(2026, 11, 20, 9, 30)
    private let zone = Fixtures.jakarta

    private enum SaveFailure: Error { case simulated }

    private func seededStore() throws -> TestStore {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        return store
    }

    /// A store using every field: a hidden subcategory, changed pins, subcategory and group budgets, notes
    /// (with a comma, a quote and a line break), sub-millisecond dates, an orphan transaction, and rollups
    /// including one with an empty name and emoji.
    private func fullStore() throws -> TestStore {
        let store = try seededStore()
        let context = store.context
        let makan = try store.subcategory(named: "Makan")
        let kopi = try store.subcategory(named: "Kopi")
        let gaji = try store.subcategory(named: "Gaji")
        let galon = try store.subcategory(named: "Galon")
        galon.isHidden = true
        galon.pinOrder = nil
        makan.pinOrder = 4
        kopi.pinOrder = 0
        try kopi.setMonthlyBudget(300_000)
        makan.name = "Makan2"
        makan.emoji = "🍜"
        let settings = try AppSettings.fetchOrCreate(in: context)
        settings.setBudget(3_000_000, for: .kebutuhan)
        settings.setBudget(500_000, for: .keinginan)

        // A custom subcategory created later, with its own sort order.
        let custom = Subcategory(name: "Kucing", emoji: "🐈", kind: .expense, group: .keinginan, sortOrder: 99, createdAt: Fixtures.date(2026, 3, 1, 8))
        context.insert(custom)

        context.insert(MoneyTransaction(
            amount: 25_000, subcategory: makan,
            date: Fixtures.date(2026, 11, 3, 12, 5, 7).addingTimeInterval(0.123_456),
            note: "Nasi, \"padang\"\nenak", createdAt: Fixtures.date(2026, 11, 3, 12, 6).addingTimeInterval(0.000_4)
        ))
        context.insert(MoneyTransaction(amount: 18_000, subcategory: kopi, date: Fixtures.date(2026, 10, 15, 7), createdAt: Fixtures.date(2026, 10, 15, 7)))
        context.insert(MoneyTransaction(amount: 8_500_000, subcategory: gaji, date: Fixtures.date(2026, 11, 1, 9), createdAt: Fixtures.date(2026, 11, 1, 9)))
        context.insert(MoneyTransaction(amount: 40_000, subcategory: galon, date: Fixtures.date(2026, 2, 1, 9), createdAt: Fixtures.date(2026, 2, 1, 9)))
        context.insert(MoneyTransaction(amount: 75_000, subcategory: custom, date: Fixtures.date(2026, 4, 1, 9), createdAt: Fixtures.date(2026, 4, 1, 9)))
        // An orphan: its subcategory was deleted (D-006).
        context.insert(MoneyTransaction(
            restoringID: UUID(), amount: 12_000, date: Fixtures.date(2026, 5, 2, 9), note: nil,
            createdAt: Fixtures.date(2026, 5, 2, 9), subcategory: nil, subcategoryID: UUID(),
            kindRaw: "expense", groupRaw: "keinginan"
        ))

        context.insert(MonthlyRollup(
            month: MonthKey(year: 2025, month: 9), subcategoryID: makan.id, total: 1_250_000, count: 31,
            name: "Makan", emoji: "🍚", kind: .expense, group: .kebutuhan
        ))
        context.insert(MonthlyRollup(
            month: MonthKey(year: 2025, month: 9), subcategoryID: UUID(), total: 5_000, count: 1,
            name: "", emoji: "", kind: .expense, group: .keinginan
        ))
        context.insert(MonthlyRollup(
            month: MonthKey(year: 2024, month: 12), subcategoryID: gaji.id, total: 8_000_000, count: 1,
            name: "Gaji", emoji: "💼", kind: .income, group: nil
        ))
        try context.save()
        return store
    }

    private func snapshot(_ store: TestStore) throws -> BackupDocument {
        try Backup.snapshot(of: store.context, exportedAt: exportedAt, appVersion: "1.0")
    }

    /// Reads through a fresh context, so a test sees what was saved, not pending changes.
    private func savedSnapshot(_ store: TestStore) throws -> BackupDocument {
        try Backup.snapshot(of: ModelContext(store.container), exportedAt: exportedAt, appVersion: "1.0")
    }

    // MARK: - Round trip

    @Test func aFullStoreRoundTripsExactly() throws {
        let source = try fullStore()
        let bytes = try snapshot(source).encoded()

        let target = try seededStore()
        try Backup.restore(try BackupDocument.decode(bytes), into: target.context)
        let restored = try savedSnapshot(target)

        #expect(try restored.encoded() == bytes, "the restored store backs up to the same bytes")
        #expect(restored == (try BackupDocument.decode(bytes)))

        // Spot checks on the models themselves.
        let galon = try target.subcategory(named: "Galon")
        #expect(galon.isHidden)
        #expect(galon.pinOrder == nil)
        let kopi = try target.subcategory(named: "Kopi")
        #expect(kopi.pinOrder == 0)
        #expect(kopi.monthlyBudget == 300_000)
        let makan = try target.subcategory(named: "Makan2")
        #expect(makan.emoji == "🍜")
        #expect(makan.pinOrder == 4)
        #expect(try target.subcategory(named: "Kucing").sortOrder == 99)
        let settings = try AppSettings.fetchOrCreate(in: target.context)
        #expect(settings.budget(for: .kebutuhan) == 3_000_000)
        #expect(settings.budget(for: .keinginan) == 500_000)
        #expect(settings.seedVersion == SeedData.version)

        let transactions = try target.context.fetch(FetchDescriptor<MoneyTransaction>())
        #expect(transactions.count == 6)
        let noted = try #require(transactions.first { $0.amount == 25_000 })
        #expect(noted.note == "Nasi, \"padang\"\nenak")
        #expect(noted.subcategory?.id == makan.id, "the relationship is rebuilt")
        let expectedDate = Fixtures.date(2026, 11, 3, 12, 5, 7).addingTimeInterval(0.123)
        #expect(abs(noted.date.timeIntervalSince(expectedDate)) < 0.000_01, "dates keep their milliseconds")
        let orphan = try #require(transactions.first { $0.amount == 12_000 })
        #expect(orphan.subcategory == nil, "an orphan stays an orphan")
        #expect(orphan.group == .keinginan)
        #expect(makan.transactions.count == 1)

        let rollups = try target.context.fetch(FetchDescriptor<MonthlyRollup>())
        #expect(rollups.count == 3)
        let empty = try #require(rollups.first { $0.total == 5_000 })
        #expect(empty.name.isEmpty && empty.emoji.isEmpty, "empty snapshot names round-trip")
        let income = try #require(rollups.first { $0.kind == .income })
        #expect(income.group == nil)
        #expect(income.month == MonthKey(year: 2024, month: 12))
    }

    /// The device's store is SQLite on disk: a restore over the seed (same subcategory ids) must replace the
    /// rows, not trip the unique constraints, and must still be there after reopening.
    @Test func aRestoreOnDiskSurvivesReopening() throws {
        let bytes = try snapshot(try fullStore()).encoded()
        let directory = FileManager.default.temporaryDirectory.appending(path: "KemanayaBackupTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "test.store")

        do {
            let container = try TestStore.containerCreation.withLock { try KemanayaStore.makeContainer(storeURL: url) }
            let context = ModelContext(container)
            try Seeder.seedIfNeeded(in: context)
            try Backup.restore(try BackupDocument.decode(bytes), into: context)
            // A second restore over the restored rows works the same way.
            try Backup.restore(try BackupDocument.decode(bytes), into: context)
        }
        let reopened = try TestStore.containerCreation.withLock { try KemanayaStore.makeContainer(storeURL: url) }
        let restored = try Backup.snapshot(of: ModelContext(reopened), exportedAt: exportedAt, appVersion: "1.0")
        #expect(try restored.encoded() == bytes)
    }

    @Test func encodingIsByteStable() throws {
        let store = try fullStore()
        let first = try snapshot(store).encoded()
        let second = try snapshot(store).encoded()
        #expect(first == second)

        // The order models come back in doesn't matter.
        var shuffled = try snapshot(store)
        shuffled.transactions.reverse()
        shuffled.subcategories.reverse()
        shuffled.rollups.reverse()
        #expect(try shuffled.normalized().encoded() == first)

        let text = try #require(String(data: first, encoding: .utf8))
        #expect(text.contains("\"formatVersion\" : 1"))
        #expect(text.contains("\"exportedAt\" : \"2026-11-20T02:30:00.000Z\""), "UTC with milliseconds")
        #expect(text.contains("\"appVersion\" : \"1.0\""))
    }

    @Test func datesRoundTripToTheMillisecond() throws {
        let date = Date(timeIntervalSince1970: 1_795_000_000.123_456)
        let text = BackupDate.string(from: date)
        #expect(text == "2026-11-18T11:06:40.123Z")
        let decoded = try #require(BackupDate.date(from: text))
        #expect(BackupDate.string(from: decoded) == text, "re-encoding a decoded date gives the same text")
        #expect(abs(decoded.timeIntervalSince1970 - 1_795_000_000.123) < 0.000_001)

        #expect(BackupDate.string(from: Date(timeIntervalSince1970: 0.9996)) == "1970-01-01T00:00:01.000Z", "rounds to the nearest millisecond")
        let before1970 = Date(timeIntervalSince1970: -1.5)
        #expect(BackupDate.string(from: before1970) == "1969-12-31T23:59:58.500Z")
        #expect(BackupDate.date(from: "1969-12-31T23:59:58.500Z") == before1970)

        #expect(BackupDate.date(from: "2026-02-31T00:00:00.000Z") == nil, "no rollover to March")
        #expect(BackupDate.date(from: "2026-11-18T11:06:40Z") == nil, "milliseconds are required")
        #expect(BackupDate.date(from: "2026-11-18T11:06:40.123+07:00") == nil)
    }

    // MARK: - Refused files

    @Test func aNewerFormatIsRefused() throws {
        let newer = Data(#"{"formatVersion": 2, "everything": "changed"}"#.utf8)
        #expect(throws: BackupError.newerFormat(2)) { try BackupDocument.decode(newer) }

        var document = try snapshot(try fullStore())
        document.formatVersion = 3
        #expect(throws: BackupError.newerFormat(3)) { try BackupDocument.decode(try document.encoded()) }
    }

    @Test func corruptFilesAreRefused() throws {
        let valid = try snapshot(try fullStore()).encoded()
        let samples: [Data] = [
            Data("not json".utf8),
            Data(),
            Data(#"{"formatVersion": 0}"#.utf8),
            Data(#"{"formatVersion": 1}"#.utf8),
            valid.prefix(valid.count / 2),
            Data(String(decoding: valid, as: UTF8.self).replacingOccurrences(of: "\"expense\"", with: "\"spending\"").utf8),
            Data(String(decoding: valid, as: UTF8.self).replacingOccurrences(of: ".000Z", with: "Z").utf8),
        ]
        for sample in samples {
            #expect(throws: BackupError.unreadable) { try BackupDocument.decode(sample) }
        }
    }

    @Test func invalidContentIsRefused() throws {
        let document = try snapshot(try fullStore())
        let firstSubcategory = document.subcategories[0]
        let firstTransaction = document.transactions[0]

        var duplicate = document
        duplicate.subcategories.append(firstSubcategory)
        #expect(throws: BackupError.duplicateID(firstSubcategory.id)) { try duplicate.validate() }

        var duplicateTransaction = document
        duplicateTransaction.transactions.append(firstTransaction)
        #expect(throws: BackupError.duplicateID(firstTransaction.id)) { try duplicateTransaction.validate() }

        var zero = document
        zero.transactions[0].amount = 0
        #expect(throws: BackupError.invalidTransaction(firstTransaction.id)) { try zero.validate() }

        var mismatch = document
        let linked = try #require(mismatch.transactions.firstIndex { tx in tx.kind == .expense && document.subcategories.contains { $0.id == tx.subcategoryID } })
        mismatch.transactions[linked].kind = .income
        mismatch.transactions[linked].group = nil
        #expect(throws: BackupError.invalidTransaction(mismatch.transactions[linked].id)) { try mismatch.validate() }

        var incomeWithGroup = document
        let income = try #require(incomeWithGroup.subcategories.firstIndex { $0.kind == .income })
        incomeWithGroup.subcategories[income].group = .kebutuhan
        #expect(throws: BackupError.invalidSubcategory(incomeWithGroup.subcategories[income].id)) { try incomeWithGroup.validate() }

        var incomeBudget = document
        incomeBudget.subcategories[income].monthlyBudget = 100_000
        #expect(throws: BackupError.invalidSubcategory(incomeBudget.subcategories[income].id)) { try incomeBudget.validate() }

        var duplicateRollup = document
        duplicateRollup.rollups.append(document.rollups[0])
        #expect(throws: BackupError.duplicateRollup(monthKey: document.rollups[0].monthKey, subcategoryID: document.rollups[0].subcategoryID)) {
            try duplicateRollup.validate()
        }

        var badMonth = document
        badMonth.rollups[0].monthKey = 202_513
        #expect(throws: BackupError.invalidRollup(monthKey: 202_513, subcategoryID: document.rollups[0].subcategoryID)) { try badMonth.validate() }

        var badBudget = document
        badBudget.settings.kebutuhanBudget = -5
        #expect(throws: BackupError.invalidSettings) { try badBudget.validate() }

        // Decoding runs the same checks.
        #expect(throws: BackupError.duplicateID(firstSubcategory.id)) { try BackupDocument.decode(try duplicate.encoded()) }
    }

    /// Amounts, budgets and rollups past what the keypad can make are refused, so no restored total can
    /// overflow (D-016).
    @Test func outOfRangeMoneyIsRefused() throws {
        let document = try snapshot(try fullStore())
        let maximum = AmountEntry.maximum

        var atCap = document
        atCap.transactions[0].amount = maximum
        try atCap.validate()

        var tooMuch = document
        tooMuch.transactions[0].amount = maximum + 1
        #expect(throws: BackupError.invalidTransaction(document.transactions[0].id)) { try tooMuch.validate() }

        var hugeAmount = document
        hugeAmount.transactions[0].amount = .max
        #expect(throws: BackupError.invalidTransaction(document.transactions[0].id)) { try BackupDocument.decode(try hugeAmount.encoded()) }

        let budgeted = try #require(document.subcategories.firstIndex { $0.monthlyBudget != nil })
        var budget = document
        budget.subcategories[budgeted].monthlyBudget = maximum + 1
        #expect(throws: BackupError.invalidSubcategory(document.subcategories[budgeted].id)) { try budget.validate() }
    }

    @Test func impossibleRollupsAreRefused() throws {
        let document = try snapshot(try fullStore())
        let rollup = document.rollups[0]
        let refusal = BackupError.invalidRollup(monthKey: rollup.monthKey, subcategoryID: rollup.subcategoryID)

        var zeroTotal = document
        zeroTotal.rollups[0].total = 0
        #expect(throws: refusal) { try BackupDocument.decode(try zeroTotal.encoded()) }

        var negativeTotal = document
        negativeTotal.rollups[0].total = -5_000
        #expect(throws: refusal) { try BackupDocument.decode(try negativeTotal.encoded()) }

        var zeroCount = document
        zeroCount.rollups[0].count = 0
        #expect(throws: refusal) { try zeroCount.validate() }

        var negativeCount = document
        negativeCount.rollups[0].count = -1
        #expect(throws: refusal) { try negativeCount.validate() }

        // Each rolled-up amount came through the keypad, so the total is at most maximum × count.
        var atCap = document
        atCap.rollups[0].count = 3
        atCap.rollups[0].total = AmountEntry.maximum * 3
        try atCap.validate()

        var overCap = atCap
        overCap.rollups[0].total += 1
        #expect(throws: refusal) { try overCap.validate() }

        // Totals that would overflow a year's sum.
        var overflow = document
        overflow.rollups[0].total = .max
        #expect(throws: refusal) { try BackupDocument.decode(try overflow.encoded()) }

        // A count whose cap passes Int64 doesn't trap: the cap is then Int64.max.
        #expect(BackupDocument.maximumRollupTotal(count: .max) == .max)
        #expect(BackupDocument.maximumRollupTotal(count: 2) == AmountEntry.maximum * 2)
    }

    /// Pins follow D-049 and D-068: at most 6 Kebutuhan, 6 Keinginan and 3 Pemasukan, each order once,
    /// never on a hidden subcategory.
    @Test func invalidPinsAreRefused() throws {
        let document = try snapshot(try fullStore())
        let pinned = document.subcategories.indices.filter { document.subcategories[$0].pinOrder != nil }
        #expect(pinned.count >= 2)

        var duplicate = document
        duplicate.subcategories[pinned[1]].pinOrder = duplicate.subcategories[pinned[0]].pinOrder
        #expect(throws: BackupError.invalidPins) { try BackupDocument.decode(try duplicate.encoded()) }

        // Every section filled to its limit restores; one more in any section is refused.
        let full = Self.pinningUpToTheLimits(document)
        #expect(full.subcategories.filter { $0.pinOrder != nil }.count == 15)
        _ = try BackupDocument.decode(try full.encoded())
        for section in PinSection.allCases {
            var tooMany = full
            let extra = try #require(tooMany.subcategories.indices.first {
                let record = tooMany.subcategories[$0]
                return record.pinOrder == nil && !record.isHidden && PinSection(kind: record.kind, group: record.group) == section
            })
            tooMany.subcategories[extra].pinOrder = 999
            #expect(throws: BackupError.invalidPins, "a pin past the \(section) limit") {
                try BackupDocument.decode(try tooMany.encoded())
            }
        }

        var hidden = document
        hidden.subcategories[pinned[0]].isHidden = true
        #expect(throws: BackupError.invalidSubcategory(document.subcategories[pinned[0]].id)) { try hidden.validate() }

        var negative = document
        negative.subcategories[pinned[0]].pinOrder = -1
        #expect(throws: BackupError.invalidSubcategory(document.subcategories[pinned[0]].id)) { try negative.validate() }
    }

    /// `document` with every Home section pinned up to its limit (D-068), new pins numbered after the old.
    private static func pinningUpToTheLimits(_ document: BackupDocument) -> BackupDocument {
        var result = document
        var counts: [PinSection: Int] = [:]
        for record in result.subcategories where record.pinOrder != nil {
            counts[PinSection(kind: record.kind, group: record.group), default: 0] += 1
        }
        var order = 100
        for index in result.subcategories.indices {
            let record = result.subcategories[index]
            let section = PinSection(kind: record.kind, group: record.group)
            guard record.pinOrder == nil, !record.isHidden, counts[section, default: 0] < section.limit else { continue }
            result.subcategories[index].pinOrder = order
            counts[section, default: 0] += 1
            order += 1
        }
        return result
    }

    @Test func badNamesAreRefused() throws {
        let document = try snapshot(try fullStore())
        let id = document.subcategories[0].id

        var empty = document
        empty.subcategories[0].name = ""
        #expect(throws: BackupError.invalidSubcategory(id)) { try empty.validate() }

        var long = document
        long.subcategories[0].name = String(repeating: "a", count: SubcategoryRules.maximumNameLength + 1)
        #expect(throws: BackupError.invalidSubcategory(id)) { try long.validate() }

        var longest = document
        longest.subcategories[0].name = String(repeating: "a", count: SubcategoryRules.maximumNameLength)
        try longest.validate()
    }

    /// D-066: a file that breaks D-062's rules is refused, not repaired: a name with spaces around or in
    /// it, or a duplicate after folding case, diacritics and width (a hidden one counts).
    @Test func namesBreakingTheEditorRulesAreRefused() throws {
        let document = try snapshot(try fullStore())
        let first = document.subcategories[0]
        let second = document.subcategories[1]

        for bad in [" \(first.name)", "\(first.name) ", "Dua kata", "\t"] {
            var spaced = document
            spaced.subcategories[0].name = bad
            #expect(throws: BackupError.invalidSubcategory(first.id), "\(bad.debugDescription)") { try spaced.validate() }
        }

        var sameCase = document
        sameCase.subcategories[1].name = first.name.uppercased()
        #expect(throws: BackupError.duplicateName(second.id)) { try sameCase.validate() }

        var accented = document
        accented.subcategories[0].name = "Kopi"
        accented.subcategories[1].name = "Kopí"
        #expect(throws: BackupError.duplicateName(second.id)) { try accented.validate() }

        var wide = document
        wide.subcategories[0].name = "Kopi"
        wide.subcategories[1].name = "Ｋｏｐｉ"
        #expect(throws: BackupError.duplicateName(second.id)) { try wide.validate() }

        let hiddenIndex = try #require(document.subcategories.firstIndex { $0.isHidden })
        let otherIndex = try #require(document.subcategories.indices.first { $0 != hiddenIndex })
        var hiddenTwin = document
        hiddenTwin.subcategories[otherIndex].name = document.subcategories[hiddenIndex].name.lowercased()
        #expect(throws: BackupError.self, "a hidden subcategory's name is taken too") { try hiddenTwin.validate() }
        #expect(throws: BackupError.duplicateName(document.subcategories[max(hiddenIndex, otherIndex)].id)) {
            try BackupDocument.decode(try hiddenTwin.encoded())
        }
    }

    /// D-066: the emoji must be exactly one emoji (``SubcategoryRules/isValidEmoji(_:)``).
    @Test func invalidEmojiIsRefused() throws {
        let document = try snapshot(try fullStore())
        let id = document.subcategories[0].id
        for bad in ["", "a", "1", "☕☕", "☕\u{FE0E}"] {
            var invalid = document
            invalid.subcategories[0].emoji = bad
            #expect(throws: BackupError.invalidSubcategory(id), "\(bad.debugDescription)") { try invalid.validate() }
        }
        var valid = document
        valid.subcategories[0].emoji = "🅿️"
        try valid.validate()
    }

    /// D-066: Kebutuhan, Keinginan and income each keep a visible subcategory, so the add sheet always has
    /// a tile (D-062). Hidden ones don't count; removing them all counts as empty too.
    @Test func aSectionWithNoVisibleSubcategoryIsRefused() throws {
        let document = try snapshot(try fullStore())
        let sections: [(TransactionKind, ExpenseGroup?)] = [(.expense, .kebutuhan), (.expense, .keinginan), (.income, nil)]
        for (kind, group) in sections {
            var allHidden = document
            for index in allHidden.subcategories.indices where allHidden.subcategories[index].kind == kind && allHidden.subcategories[index].group == group {
                allHidden.subcategories[index].isHidden = true
                allHidden.subcategories[index].pinOrder = nil
            }
            #expect(throws: BackupError.noVisibleSubcategory(kind: kind, group: group)) { try allHidden.validate() }

            var none = document
            none.subcategories.removeAll { $0.kind == kind && $0.group == group }
            #expect(throws: BackupError.noVisibleSubcategory(kind: kind, group: group)) { try BackupDocument.decode(try none.encoded()) }
        }
        try document.validate()
    }

    @Test func anInvalidDocumentChangesNothing() throws {
        let store = try fullStore()
        let before = try savedSnapshot(store)
        var document = try snapshot(try seededStore())
        document.transactions.append(.init(
            id: UUID(), amount: -1, date: now, note: nil, createdAt: now,
            subcategoryID: document.subcategories[0].id, kind: document.subcategories[0].kind, group: document.subcategories[0].group
        ))
        #expect(throws: BackupError.self) { try Backup.restore(document, into: store.context) }
        #expect(!store.context.hasChanges)
        #expect(try savedSnapshot(store) == before)
    }

    @Test func aFailedSaveRollsEverythingBack() throws {
        let store = try fullStore()
        let before = try savedSnapshot(store)
        let other = try snapshot(try seededStore())

        #expect(throws: SaveFailure.self) {
            try Backup.restore(other, into: store.context) { _ in throw SaveFailure.simulated }
        }
        #expect(!store.context.hasChanges, "nothing is left pending")
        #expect(try snapshot(store) == before, "the context reads the old data")
        #expect(try savedSnapshot(store) == before, "and so does the store")
        let makan = try store.subcategory(named: "Makan2")
        #expect(makan.transactions.count == 1, "relationships are intact")
        #expect(try store.context.fetch(FetchDescriptor<MoneyTransaction>()).filter { $0.amount == 25_000 }.first?.subcategory?.id == makan.id)
    }

    // MARK: - Restore

    @Test func restoreReplacesAllData() throws {
        let store = try fullStore()
        // A small backup from another device: one subcategory per section, one transaction, no rollups.
        let food = UUID()
        let fun = UUID()
        let salary = UUID()
        let document = BackupDocument(
            exportedAt: exportedAt,
            appVersion: "1.0",
            subcategories: [
                .init(id: food, name: "Food", emoji: "🍔", kind: .expense, group: .kebutuhan, sortOrder: 0, isHidden: false, pinOrder: 0, monthlyBudget: nil, createdAt: now),
                .init(id: fun, name: "Fun", emoji: "🎮", kind: .expense, group: .keinginan, sortOrder: 0, isHidden: false, pinOrder: nil, monthlyBudget: nil, createdAt: now),
                .init(id: salary, name: "Salary", emoji: "💰", kind: .income, group: nil, sortOrder: 0, isHidden: false, pinOrder: nil, monthlyBudget: nil, createdAt: now),
            ],
            transactions: [
                .init(id: UUID(), amount: 99_000, date: now, note: "x", createdAt: now, subcategoryID: food, kind: .expense, group: .kebutuhan),
            ],
            rollups: [],
            settings: .init(kebutuhanBudget: nil, keinginanBudget: 100_000, seedVersion: 1)
        )
        try Backup.restore(document, into: store.context)

        let fresh = ModelContext(store.container)
        #expect(try fresh.fetch(FetchDescriptor<Subcategory>()).map(\.name).sorted() == ["Food", "Fun", "Salary"])
        #expect(try fresh.fetch(FetchDescriptor<MoneyTransaction>()).map(\.amount) == [99_000])
        #expect(try fresh.fetchCount(FetchDescriptor<MonthlyRollup>()) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<AppSettings>()) == 1, "one settings row")
        let settings = try AppSettings.fetchOrCreate(in: fresh)
        #expect(settings.budget(for: .kebutuhan) == nil)
        #expect(settings.budget(for: .keinginan) == 100_000)
        #expect(try savedSnapshot(store) == document)
    }

    /// An old backup brings back months now before the raw window; retention then rolls them up (D-059).
    @Test func restoreThenRetentionRollsUpOldMonths() throws {
        let source = try seededStore()
        let makan = try source.subcategory(named: "Makan")
        source.context.insert(MoneyTransaction(amount: 40_000, subcategory: makan, date: Fixtures.date(2025, 9, 10)))
        source.context.insert(MoneyTransaction(amount: 10_000, subcategory: makan, date: Fixtures.date(2025, 9, 20)))
        source.context.insert(MoneyTransaction(amount: 30_000, subcategory: makan, date: Fixtures.date(2025, 11, 5)))
        source.context.insert(MonthlyRollup(
            month: MonthKey(year: 2025, month: 9), subcategoryID: makan.id, total: 5_000, count: 1,
            name: "Makan", emoji: "🍚", kind: .expense, group: .kebutuhan
        ))
        try source.context.save()
        let document = try snapshot(source)

        let target = try seededStore()
        try Backup.restore(document, into: target.context)
        let report = try Retention.run(in: target.context, now: now, timeZone: zone)

        #expect(report.rolledUpMonths == [MonthKey(year: 2025, month: 9)])
        #expect(try target.context.fetch(FetchDescriptor<MoneyTransaction>()).map(\.amount) == [30_000])
        let rollup = try #require(try target.context.fetch(FetchDescriptor<MonthlyRollup>()).first)
        #expect(rollup.total == 55_000, "added into the restored rollup")
        #expect(rollup.count == 3)
    }

    @Test func previewSummarizesTheFile() throws {
        let document = try snapshot(try fullStore())
        let preview = document.preview
        #expect(preview.exportedAt == exportedAt)
        #expect(preview.appVersion == "1.0")
        #expect(preview.transactionCount == 6)
        #expect(preview.rollupCount == 3)
        #expect(preview.subcategoryCount == SeedData.sections.joined().count + 1)
        #expect(preview.transactionDates?.lowerBound == Fixtures.date(2026, 2, 1, 9))
        #expect(preview.transactionDates?.upperBound == Fixtures.date(2026, 11, 3, 12, 5, 7).addingTimeInterval(0.123_456))

        let empty = try snapshot(try seededStore()).preview
        #expect(empty.transactionCount == 0)
        #expect(empty.transactionDates == nil)
    }

    @Test func aSnapshotNeverInsertsSettings() throws {
        let store = try TestStore()
        let document = try snapshot(store)
        #expect(document.settings == .init(kebutuhanBudget: nil, keinginanBudget: nil, seedVersion: 0))
        #expect(!store.context.hasChanges)
        #expect(try store.context.fetchCount(FetchDescriptor<AppSettings>()) == 0)
    }

    // MARK: - Fresh install

    @Test func freshInstallMeansNoTransactionsAndNoRollups() throws {
        let store = try seededStore()
        #expect(try Backup.isFreshInstall(store.context), "the seed doesn't count")

        let makan = try store.subcategory(named: "Makan")
        let transaction = MoneyTransaction(amount: 10_000, subcategory: makan, date: now)
        store.context.insert(transaction)
        try store.context.save()
        #expect(try !Backup.isFreshInstall(store.context))

        store.context.delete(transaction)
        store.context.insert(MonthlyRollup(
            month: MonthKey(year: 2024, month: 1), subcategoryID: makan.id, total: 1, count: 1,
            name: "Makan", emoji: "🍚", kind: .expense, group: .kebutuhan
        ))
        try store.context.save()
        #expect(try !Backup.isFreshInstall(store.context), "rollups alone are history too")
    }
}
