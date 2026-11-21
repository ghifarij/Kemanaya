/// What the subcategory editor is holding (D-062): a pure value, so every rule the sheet shows is tested
/// here and the view only draws it. ``Ledger/addSubcategory(name:emoji:kind:group:monthlyBudget:now:)`` and
/// ``Ledger/updateSubcategory(_:name:emoji:monthlyBudget:)`` check the same rules again when saving.
public struct SubcategoryDraft: Equatable, Sendable {
    /// Fixed: the editor adds into the kind on screen, and an edit keeps its kind (D-004).
    public let kind: TransactionKind
    /// The expense group, chosen only while adding (D-004); always nil for income (D-005).
    public var group: ExpenseGroup? {
        didSet { if kind == .income { group = nil } }
    }
    /// As typed; trimmed when checked and saved.
    public var name: String
    /// As typed. Set it through ``setEmojiInput(_:)`` so a newly typed emoji replaces the old one.
    public private(set) var emoji: String
    /// Expenses only; nil when none. Zero is not a budget (D-062).
    public var monthlyBudget: Int64? {
        didSet { if kind == .income || (monthlyBudget ?? 0) <= 0 { monthlyBudget = nil } }
    }

    public init(kind: TransactionKind, group: ExpenseGroup?, name: String = "", emoji: String = "", monthlyBudget: Int64? = nil) {
        self.kind = kind
        self.group = kind == .expense ? group ?? .kebutuhan : nil
        self.name = name
        self.emoji = emoji
        self.monthlyBudget = kind == .expense && (monthlyBudget ?? 0) > 0 ? monthlyBudget : nil
    }

    /// The editor's text for an existing subcategory.
    public init(_ subcategory: Subcategory) {
        self.init(
            kind: subcategory.kind,
            group: subcategory.group,
            name: subcategory.name,
            emoji: subcategory.emoji,
            monthlyBudget: subcategory.monthlyBudget
        )
    }

    /// The name as it will be stored.
    public var trimmedName: String { SubcategoryRules.normalizedName(name) }

    /// The live counter's number, "n/10" (D-062).
    public var nameLength: Int { trimmedName.count }

    /// Why the name can't be saved, or nil.
    /// - Parameter takenNames: every other subcategory's name (``SubcategoryRules/nameProblem(_:takenNames:)``).
    public func nameProblem(takenNames: some Sequence<String>) -> SubcategoryNameProblem? {
        SubcategoryRules.nameProblem(name, takenNames: takenNames)
    }

    /// True when the emoji field holds exactly one emoji (D-007).
    public var hasValidEmoji: Bool { SubcategoryRules.isValidEmoji(emoji) }

    /// True when Simpan can be tapped: a valid emoji and a valid, free name (D-062).
    public func canSave(takenNames: some Sequence<String>) -> Bool {
        hasValidEmoji && nameProblem(takenNames: takenNames) == nil
    }

    /// Takes the emoji field's new text. Spaces are dropped, and when more than one character is there
    /// (a new emoji typed after the old one), only the last is kept, so typing an emoji replaces the old one.
    public mutating func setEmojiInput(_ text: String) {
        let trimmed = text.filter { !$0.isWhitespace }
        emoji = trimmed.last.map(String.init) ?? ""
    }
}
