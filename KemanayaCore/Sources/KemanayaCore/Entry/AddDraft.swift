import Foundation

/// Everything the add / edit sheet holds and every rule it follows (D-013, D-043, D-044), as a plain value.
/// The sheet draws it and forwards taps; it never decides anything itself (D-036).
///
/// Two ways to save:
/// - **Add** (``Mode/add``): tapping a subcategory saves at once, so "+" → amount → subcategory is 3 taps.
///   While the amount is 0 the tiles are disabled.
/// - **Selected subcategory** (``Mode/preselected``, ``Mode/edit(originalSubcategoryID:originalDate:)``):
///   one subcategory is highlighted. Tapping another selects it; tapping the highlighted one saves,
///   the same as the Simpan button (D-044).
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
        /// "+": a new transaction, a tile tap saves.
        case add
        /// A pinned card's quick add (Phase 5): a new transaction with a subcategory highlighted.
        case preselected
        /// Editing. `originalSubcategoryID` is nil only for an orphaned transaction (D-006).
        case edit(originalSubcategoryID: UUID?, originalDate: Date)
    }

    /// What a tile tap asks the sheet to do.
    public enum TapOutcome: Equatable, Sendable {
        /// Save into this subcategory now.
        case save(UUID)
        /// The highlight moved (or stayed); nothing to save yet.
        case selected
        /// The tile is disabled (add mode with no amount).
        case ignored
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

    /// Preselected and edit modes save with a Simpan button; add saves on a tile tap.
    public var savesWithButton: Bool { mode != .add }

    /// The selection, if it belongs to the kind on screen.
    public var selectedOfCurrentKind: Pick? {
        selection.flatMap { $0.kind == kind ? $0 : nil }
    }

    /// Simpan is enabled: an amount and a selected subcategory of the current kind.
    public var canSave: Bool {
        !entry.isEmpty && selectedOfCurrentKind != nil
    }

    /// Only add mode saves on any tap, so only there an empty amount disables the tiles.
    public var tilesDisabled: Bool {
        mode == .add && entry.isEmpty
    }

    /// True when tapping `subcategory` would save (for the tile's VoiceOver hint).
    public func tapSaves(_ subcategory: Pick) -> Bool {
        guard !entry.isEmpty else { return false }
        return mode == .add || subcategory == selectedOfCurrentKind
    }

    // MARK: - Changes

    /// Applies a tile tap.
    public mutating func tap(_ subcategory: Pick) -> TapOutcome {
        if mode == .add {
            return entry.isEmpty ? .ignored : .save(subcategory.id)
        }
        if subcategory == selectedOfCurrentKind, canSave {
            return .save(subcategory.id)
        }
        selection = subcategory
        return .selected
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
