import Foundation

/// The JSON backup file (D-019, D-060): every subcategory, transaction, rollup and the settings, so a
/// restore gives back exactly what was backed up.
///
/// - **Versioned:** ``formatVersion`` is 1. A file with a newer version is refused before anything else
///   is read (``BackupError/newerFormat(_:)``), so an old app never half-reads a newer file.
/// - **Exact:** dates are written as UTC ISO 8601 strings with milliseconds (`2026-11-20T05:12:33.123Z`,
///   ``BackupDate``), so every date round-trips to the millisecond; money is `Int64` rupiah (D-016).
/// - **Stable:** keys are sorted and ``normalized()`` orders every array by its data, so backing up the
///   same data twice (with the same ``exportedAt``) gives byte-identical files.
/// - Enum values are the persisted raw values (``TransactionKind``, ``ExpenseGroup``), never display names.
/// - The backup folder's bookmark is not in here: it only works on the device that made it (D-060).
public struct BackupDocument: Codable, Equatable, Sendable {
    /// The newest format this app reads and the one it writes.
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    /// When the backup was made.
    public var exportedAt: Date
    /// The app's marketing version that wrote it, e.g. `1.0`. Informational only.
    public var appVersion: String
    public var subcategories: [SubcategoryRecord]
    public var transactions: [TransactionRecord]
    public var rollups: [RollupRecord]
    public var settings: SettingsRecord

    public init(
        formatVersion: Int = BackupDocument.currentFormatVersion,
        exportedAt: Date,
        appVersion: String,
        subcategories: [SubcategoryRecord],
        transactions: [TransactionRecord],
        rollups: [RollupRecord],
        settings: SettingsRecord
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.subcategories = subcategories
        self.transactions = transactions
        self.rollups = rollups
        self.settings = settings
    }

    /// A ``Subcategory``, every stored field.
    public struct SubcategoryRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var emoji: String
        public var kind: TransactionKind
        /// Nil for income (D-005).
        public var group: ExpenseGroup?
        public var sortOrder: Int
        public var isHidden: Bool
        /// Nil when not pinned (D-012).
        public var pinOrder: Int?
        /// Rupiah; nil = no budget (D-041).
        public var monthlyBudget: Int64?
        public var createdAt: Date

        public init(
            id: UUID, name: String, emoji: String, kind: TransactionKind, group: ExpenseGroup?, sortOrder: Int,
            isHidden: Bool, pinOrder: Int?, monthlyBudget: Int64?, createdAt: Date
        ) {
            self.id = id
            self.name = name
            self.emoji = emoji
            self.kind = kind
            self.group = group
            self.sortOrder = sortOrder
            self.isHidden = isHidden
            self.pinOrder = pinOrder
            self.monthlyBudget = monthlyBudget
            self.createdAt = createdAt
        }
    }

    /// A ``MoneyTransaction``, every stored field. `kind` and `group` are its copies (they equal its
    /// subcategory's), kept so an orphan whose subcategory is gone (D-006) still restores with them.
    public struct TransactionRecord: Codable, Equatable, Sendable {
        public var id: UUID
        /// Rupiah, > 0 (D-016).
        public var amount: Int64
        public var date: Date
        /// Nil when there is none; never blank.
        public var note: String?
        public var createdAt: Date
        public var subcategoryID: UUID
        public var kind: TransactionKind
        public var group: ExpenseGroup?

        public init(
            id: UUID, amount: Int64, date: Date, note: String?, createdAt: Date, subcategoryID: UUID,
            kind: TransactionKind, group: ExpenseGroup?
        ) {
            self.id = id
            self.amount = amount
            self.date = date
            self.note = note
            self.createdAt = createdAt
            self.subcategoryID = subcategoryID
            self.kind = kind
            self.group = group
        }
    }

    /// A ``MonthlyRollup``, every stored field. Name and emoji are snapshots and may be empty (an orphan's).
    public struct RollupRecord: Codable, Equatable, Sendable {
        /// ``MonthKey/rawValue``, `yyyymm`.
        public var monthKey: Int
        public var subcategoryID: UUID
        public var total: Int64
        public var count: Int
        public var name: String
        public var emoji: String
        public var kind: TransactionKind
        public var group: ExpenseGroup?

        public init(
            monthKey: Int, subcategoryID: UUID, total: Int64, count: Int, name: String, emoji: String,
            kind: TransactionKind, group: ExpenseGroup?
        ) {
            self.monthKey = monthKey
            self.subcategoryID = subcategoryID
            self.total = total
            self.count = count
            self.name = name
            self.emoji = emoji
            self.kind = kind
            self.group = group
        }
    }

    /// The ``AppSettings`` row.
    public struct SettingsRecord: Codable, Equatable, Sendable {
        /// Rupiah; nil = no budget (D-010).
        public var kebutuhanBudget: Int64?
        public var keinginanBudget: Int64?
        /// ``SeedData/version`` already applied.
        public var seedVersion: Int

        public init(kebutuhanBudget: Int64?, keinginanBudget: Int64?, seedVersion: Int) {
            self.kebutuhanBudget = kebutuhanBudget
            self.keinginanBudget = keinginanBudget
            self.seedVersion = seedVersion
        }
    }
}

// MARK: - Order

extension BackupDocument {
    /// The same document with every array in a fixed order taken from the data alone: subcategories by
    /// kind, group, sort order and id; transactions by date and id; rollups by month and subcategory id.
    /// Snapshots are normalized, so equal data always encodes to equal bytes.
    public func normalized() -> BackupDocument {
        var copy = self
        copy.subcategories.sort {
            ($0.kind.rawValue, $0.group?.rawValue ?? "", $0.sortOrder, $0.id.uuidString)
                < ($1.kind.rawValue, $1.group?.rawValue ?? "", $1.sortOrder, $1.id.uuidString)
        }
        copy.transactions.sort {
            ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString)
        }
        copy.rollups.sort {
            ($0.monthKey, $0.subcategoryID.uuidString) < ($1.monthKey, $1.subcategoryID.uuidString)
        }
        return copy
    }
}

// MARK: - Encoding and decoding

extension BackupDocument {
    /// The file's bytes: UTF-8 JSON, pretty-printed (readable in the Files app), keys sorted, slashes
    /// unescaped, dates as ``BackupDate`` strings.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(BackupDate.string(from: date))
        }
        return try encoder.encode(self)
    }

    /// Reads and validates a backup file.
    ///
    /// The format version is read first, on its own, so a file from a newer app is reported as such even
    /// when the rest of its structure has changed.
    /// - Throws: ``BackupError/unreadable`` when it isn't a Kemanaya backup or can't be decoded,
    ///   ``BackupError/newerFormat(_:)`` when it was written by a newer format, or the problem
    ///   ``validate()`` found.
    public static func decode(_ data: Data) throws(BackupError) -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = BackupDate.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a backup date: \(text)")
            }
            return date
        }
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw .unreadable
        }
        guard header.formatVersion <= currentFormatVersion else { throw .newerFormat(header.formatVersion) }
        guard header.formatVersion >= 1 else { throw .unreadable }

        let document: BackupDocument
        do {
            document = try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw .unreadable
        }
        try document.validate()
        return document
    }

    /// Just the version, decodable from any format.
    private struct Header: Decodable {
        let formatVersion: Int
    }
}

// MARK: - Validation

extension BackupDocument {
    /// Checks everything a restore relies on, so a restore never inserts a model that breaks an invariant
    /// (or trips a model's precondition):
    ///
    /// - ids are unique: subcategories, transactions, and (month, subcategory) for rollups;
    /// - expenses have a group and income has none (``SubcategoryRules/isValidPlacement(kind:group:)``),
    ///   for subcategories, transactions and rollups;
    /// - subcategory names are 1…``SubcategoryRules/maximumNameLength`` characters (D-007);
    /// - amounts are between 1 and ``AmountEntry/maximum`` (the keypad's cap); subcategory budgets, when set,
    ///   too; group budgets, when set, are > 0; income has no budget (D-016, D-041);
    /// - pins (D-012, D-049): at most ``SubcategoryRules/maximumPins``, no two with the same order, none
    ///   negative and none hidden;
    /// - a transaction's kind and group equal its subcategory's;
    /// - rollup months are valid `yyyymm` values, counts are > 0, and totals are > 0 and at most
    ///   ``AmountEntry/maximum`` × count (each rolled-up amount came through the keypad).
    ///
    /// With every amount capped, no sum the app makes can come near `Int64`'s limit in real data, and the
    /// sums clamp instead of trapping should one ever get there (``MonthSummary``, ``Retention``).
    ///
    /// A transaction whose subcategory is not in the file is allowed: it restores as an orphan, the way
    /// it was backed up (D-006), and still counts in totals.
    public func validate() throws(BackupError) {
        let amounts = Int64(1)...AmountEntry.maximum
        var subcategoriesByID: [UUID: SubcategoryRecord] = [:]
        var pinOrders = Set<Int>()
        for subcategory in subcategories {
            guard subcategoriesByID.updateValue(subcategory, forKey: subcategory.id) == nil else {
                throw .duplicateID(subcategory.id)
            }
            guard SubcategoryRules.isValidPlacement(kind: subcategory.kind, group: subcategory.group),
                  !subcategory.name.isEmpty,
                  subcategory.name.count <= SubcategoryRules.maximumNameLength
            else { throw .invalidSubcategory(subcategory.id) }
            if let budget = subcategory.monthlyBudget, !amounts.contains(budget) || subcategory.kind == .income {
                throw .invalidSubcategory(subcategory.id)
            }
            if let pinOrder = subcategory.pinOrder {
                // Hiding unpins (D-049), so a pinned hidden subcategory can't come from the app.
                guard pinOrder >= 0, !subcategory.isHidden else { throw .invalidSubcategory(subcategory.id) }
                guard pinOrders.insert(pinOrder).inserted else { throw .invalidPins }
            }
        }
        guard pinOrders.count <= SubcategoryRules.maximumPins else { throw .invalidPins }

        var transactionIDs = Set<UUID>()
        for transaction in transactions {
            guard transactionIDs.insert(transaction.id).inserted else { throw .duplicateID(transaction.id) }
            guard amounts.contains(transaction.amount),
                  SubcategoryRules.isValidPlacement(kind: transaction.kind, group: transaction.group)
            else { throw .invalidTransaction(transaction.id) }
            if let subcategory = subcategoriesByID[transaction.subcategoryID],
               subcategory.kind != transaction.kind || subcategory.group != transaction.group {
                throw .invalidTransaction(transaction.id)
            }
        }

        var rollupKeys = Set<String>()
        for rollup in rollups {
            guard rollupKeys.insert("\(rollup.monthKey)-\(rollup.subcategoryID)").inserted else {
                throw .duplicateRollup(monthKey: rollup.monthKey, subcategoryID: rollup.subcategoryID)
            }
            guard MonthKey(rawValue: rollup.monthKey) != nil,
                  rollup.count > 0,
                  rollup.total > 0,
                  rollup.total <= Self.maximumRollupTotal(count: rollup.count),
                  SubcategoryRules.isValidPlacement(kind: rollup.kind, group: rollup.group)
            else { throw .invalidRollup(monthKey: rollup.monthKey, subcategoryID: rollup.subcategoryID) }
        }

        for budget in [settings.kebutuhanBudget, settings.keinginanBudget] {
            if let budget, budget <= 0 { throw .invalidSettings }
        }
    }

    /// The largest total a rollup of `count` transactions can have: each was at most
    /// ``AmountEntry/maximum``. A count so large that the product passes `Int64` gets `Int64.max`, the
    /// most generous cap there is, instead of trapping.
    static func maximumRollupTotal(count: Int) -> Int64 {
        let (product, overflow) = AmountEntry.maximum.multipliedReportingOverflow(by: Int64(count))
        return overflow ? .max : product
    }
}

// MARK: - Preview

/// What the restore confirmation shows before anything changes (D-060): "Ganti semua data dengan cadangan ini?"
public struct BackupPreview: Equatable, Sendable {
    public let exportedAt: Date
    public let appVersion: String
    public let transactionCount: Int
    public let rollupCount: Int
    public let subcategoryCount: Int
    /// The oldest and newest transaction dates; nil when the file has no transactions.
    public let transactionDates: ClosedRange<Date>?
}

extension BackupDocument {
    public var preview: BackupPreview {
        let dates = transactions.map(\.date)
        let range = dates.min().flatMap { oldest in dates.max().map { oldest...$0 } }
        return BackupPreview(
            exportedAt: exportedAt,
            appVersion: appVersion,
            transactionCount: transactions.count,
            rollupCount: rollups.count,
            subcategoryCount: subcategories.count,
            transactionDates: range
        )
    }
}

// MARK: - Dates

/// The backup's date format: UTC ISO 8601 with exactly three fraction digits, `2026-11-20T05:12:33.123Z`.
///
/// Built from whole milliseconds with integer arithmetic, not a date formatter, so the round trip is exact:
/// a date is rounded to the nearest millisecond once, and re-encoding a decoded date gives the same text.
public enum BackupDate {
    /// Rounds `date` to the nearest millisecond. Years outside 1…9999 don't fit the format; the app's
    /// dates never get near them.
    public static func string(from date: Date) -> String {
        let milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded())
        // Floor division, so dates before 1970 keep a positive fraction.
        let seconds = milliseconds >= 0 ? milliseconds / 1000 : (milliseconds - 999) / 1000
        let fraction = milliseconds - seconds * 1000
        let calendar = Calendar.gregorian(in: .gmt)
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: Date(timeIntervalSince1970: TimeInterval(seconds))
        )
        return String(
            format: "%04ld-%02ld-%02ldT%02ld:%02ld:%02ld.%03ldZ",
            parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!, parts.second!, Int(fraction)
        )
    }

    /// Parses ``string(from:)``'s format exactly; anything else is nil.
    public static func date(from text: String) -> Date? {
        let characters = Array(text.utf8)
        // yyyy-MM-ddTHH:mm:ss.SSSZ
        guard characters.count == 24,
              characters[4] == UInt8(ascii: "-"), characters[7] == UInt8(ascii: "-"),
              characters[10] == UInt8(ascii: "T"), characters[13] == UInt8(ascii: ":"),
              characters[16] == UInt8(ascii: ":"), characters[19] == UInt8(ascii: "."),
              characters[23] == UInt8(ascii: "Z")
        else { return nil }
        func number(_ range: Range<Int>) -> Int? {
            var value = 0
            for index in range {
                let digit = Int(characters[index]) - Int(UInt8(ascii: "0"))
                guard (0...9).contains(digit) else { return nil }
                value = value * 10 + digit
            }
            return value
        }
        guard let year = number(0..<4), let month = number(5..<7), let day = number(8..<10),
              let hour = number(11..<13), let minute = number(14..<16), let second = number(17..<19),
              let fraction = number(20..<23),
              year >= 1, (1...12).contains(month), (1...31).contains(day),
              hour < 24, minute < 60, second < 60
        else { return nil }
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        let calendar = Calendar.gregorian(in: .gmt)
        // Reject dates the calendar would roll over, e.g. 31 February.
        guard let whole = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: whole)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        let milliseconds = Int64(whole.timeIntervalSince1970) * 1000 + Int64(fraction)
        return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
