import Foundation

/// Everything the add / edit sheet holds and every rule it follows (D-013, D-043, D-044, D-067), as a
/// plain value. The sheet draws it and forwards taps; it never decides anything itself (D-036).
///
/// One way to save, in every mode (D-067): tapping a subcategory only selects it (single selection), and
/// Simpan saves once there is an amount and a selected subcategory of the kind on screen (``canSave``).
/// A tap never saves, so a mistaken tap logs nothing.
///
/// Switching ``kind`` keeps the amount and remembers the selection: it only counts while it matches the
/// kind on screen (``selectedOfCurrentKind``), so switching back restores it.
public struct AddDraft: Equatable, Sendable {
    /// A subcategory as the draft needs it: identity and kind. Models stay in the view.
    public struct Pick: Hashable, Sendable {
        public let id: UUID
        public let kind: TransactionKind

        public init(id: UUID, kind: TransactionKind) {
            self.id = id
            self.kind = kind
        }
    }

    public enum Mode: Equatable, Sendable {
        /// "+": a new transaction, nothing selected.
        case add
        /// A pinned card's quick add (Phase 5): a new transaction with a subcategory highlighted.
        case preselected
        /// Editing. `originalSubcategoryID` is nil only for an orphaned transaction (D-006).
        case edit(originalSubcategoryID: UUID?, originalDate: Date)
    }

    public let mode: Mode
    public var entry: AmountEntry
    /// The kind on screen. Changing it keeps ``entry`` and ``selection``.
    public var kind: TransactionKind
    /// The highlighted subcategory, possibly of the other kind (see ``selectedOfCurrentKind``).
    public private(set) var selection: Pick?
    public var note: String
    /// The date shown in the picker. Change it with ``setDate(_:)``.
    public private(set) var date: Date
    /// True once the user picked a date, so ``dateToSave(now:timeZone:)`` uses it.
    public private(set) var isDateChanged = false

    private init(mode: Mode, amount: Int64, kind: TransactionKind, selection: Pick?, note: String, date: Date) {
        self.mode = mode
        self.entry = AmountEntry(amount: amount)
        self.kind = kind
        self.selection = selection
        self.note = note
        self.date = date
    }

    /// "+": empty amount, Pengeluaran (D-043), nothing selected, today.
    public static func add(now: Date) -> AddDraft {
        AddDraft(mode: .add, amount: 0, kind: .expense, selection: nil, note: "", date: now)
    }

    /// A pinned card's quick add. A hidden subcategory is never preselected: new entries can't go into
    /// one (D-006), so the sheet opens on its kind with nothing highlighted instead of failing on save.
    public static func preselected(_ subcategory: Pick, isHidden: Bool, now: Date) -> AddDraft {
        AddDraft(mode: .preselected, amount: 0, kind: subcategory.kind, selection: isHidden ? nil : subcategory, note: "", date: now)
    }

    /// Editing an existing transaction: everything prefilled.
    /// - Parameter subcategory: nil for an orphaned transaction; the user then picks one.
    public static func edit(amount: Int64, kind: TransactionKind, subcategory: Pick?, date: Date, note: String?) -> AddDraft {
        AddDraft(
            mode: .edit(originalSubcategoryID: subcategory?.id, originalDate: date),
            amount: amount,
            kind: kind,
            selection: subcategory,
            note: note ?? "",
            date: date
        )
    }

    // MARK: - Derived

    /// The subcategory the grid shows even if hidden: the edited transaction's own, so an edit never
    /// silently moves it. Nil otherwise (see ``Ledger/gridSections(for:including:)``).
    public var includedHiddenSubcategoryID: UUID? {
        if case .edit(let id, _) = mode { id } else { nil }
    }

    /// The edited transaction's date, kept selectable even when outside the entry dates (older than the
    /// raw window, or after this month).
    public var originalDate: Date? {
        if case .edit(_, let date) = mode { date } else { nil }
    }

    /// The amount keypad is up when the sheet opens: adding ("+", a pinned card's quick add) starts with
    /// typing the amount; editing opens with nothing focused, so the whole grid is in view (D-067).
    public var focusesAmountOnOpen: Bool {
        if case .edit = mode { false } else { true }
    }

    /// The selection, if it belongs to the kind on screen.
    public var selectedOfCurrentKind: Pick? {
        selection.flatMap { $0.kind == kind ? $0 : nil }
    }

    /// Simpan is enabled: an amount and a selected subcategory of the current kind.
    public var canSave: Bool {
        !entry.isEmpty && selectedOfCurrentKind != nil
    }

    // MARK: - Changes

    /// Applies a tile tap: selects `subcategory`, whatever the amount. It never saves, and tapping the
    /// selected tile again keeps it selected (D-067).
    public mutating func select(_ subcategory: Pick) {
        selection = subcategory
    }

    /// The user picked a date in the picker.
    public mutating func setDate(_ newDate: Date) {
        guard newDate != date else { return }
        date = newDate
        isDateChanged = true
    }

    /// The date to save with, resolved at the moment of saving:
    /// - Date untouched: a new entry is dated `now` (not when the sheet opened); an edit keeps its date.
    /// - A day picked: that calendar day at the time of day of `now` (new entry) or of the original
    ///   date (edit). The picker only chooses a day; its time of day is whenever the sheet opened.
    /// - Then clamped into ``RetentionWindow/entryDates(now:timeZone:keeping:)`` (D-044).
    public func dateToSave(now: Date, timeZone: TimeZone) -> Date {
        let reference = originalDate ?? now
        let resolved = isDateChanged ? Self.day(of: date, atTimeOf: reference, in: timeZone) : reference
        return RetentionWindow.clampedEntryDate(resolved, now: now, timeZone: timeZone, keeping: originalDate)
    }

    /// The Gregorian calendar day of `day` at the wall-clock time of `time`, in `timeZone`.
    static func day(of day: Date, atTimeOf time: Date, in timeZone: TimeZone) -> Date {
        let calendar = Calendar.gregorian(in: timeZone)
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        let clock = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: time)
        components.hour = clock.hour
        components.minute = clock.minute
        components.second = clock.second
        components.nanosecond = clock.nanosecond
        return calendar.date(from: components) ?? day
    }
}
