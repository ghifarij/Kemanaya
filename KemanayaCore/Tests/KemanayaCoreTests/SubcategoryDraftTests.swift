@testable import KemanayaCore
import Testing

/// The subcategory editor's rules (D-004, D-005, D-007, D-062) as a pure value, and the shared name rules
/// in ``SubcategoryRules``.
struct SubcategoryDraftTests {
    private let taken = ["Kopi", "Makan", "Hadiah"]

    // MARK: - Name rules

    @Test(arguments: [
        ("Kopi", "Kopi"),
        ("  Kopi \n", "Kopi"),
        ("", ""),
    ])
    func normalizedNameTrims(input: String, expected: String) {
        #expect(SubcategoryRules.normalizedName(input) == expected)
    }

    @Test func comparisonKeyIgnoresCaseDiacriticsAndWidth() {
        let key = SubcategoryRules.comparisonKey("Kopi")
        for variant in ["kopi", "KOPI", "Kópi", " kopi ", "ＫＯＰＩ"] {
            #expect(SubcategoryRules.comparisonKey(variant) == key, "\(variant)")
        }
        #expect(SubcategoryRules.comparisonKey("Kopa") != key)
    }

    @Test(arguments: [
        ("", SubcategoryNameProblem?.some(.empty)),
        ("  ", .some(.empty)),
        ("Es teh", .some(.notOneWord)),
        ("Pendidikanku", .some(.tooLong)),
        ("kópi", .some(.taken)),
        ("HADIAH", .some(.taken)),
        ("Bakso", nil),
        (" Bakso ", nil),
        ("Abcdefghij", nil),
    ])
    func nameProblem(name: String, problem: SubcategoryNameProblem?) {
        #expect(SubcategoryRules.nameProblem(name, takenNames: taken) == problem)
    }

    /// The order of the checks: a long phrase is reported as more than one word first.
    @Test func moreThanOneWordIsReportedBeforeLength() {
        #expect(SubcategoryRules.nameProblem("Bayar kos bulanan", takenNames: []) == .notOneWord)
    }

    // MARK: - Draft

    @Test func aNewExpenseStartsInKebutuhanWithNothingTyped() {
        let draft = SubcategoryDraft(kind: .expense, group: nil)
        #expect(draft.group == .kebutuhan)
        #expect(draft.name.isEmpty && draft.emoji.isEmpty && draft.monthlyBudget == nil)
        #expect(!draft.canSave(takenNames: taken))
    }

    @Test func incomeNeverHasAGroupOrABudget() {
        var draft = SubcategoryDraft(kind: .income, group: .keinginan, monthlyBudget: 100_000)
        #expect(draft.group == nil)
        #expect(draft.monthlyBudget == nil)
        draft.group = .kebutuhan
        draft.monthlyBudget = 50_000
        #expect(draft.group == nil, "income has no group (D-005)")
        #expect(draft.monthlyBudget == nil, "income has no budget (D-041)")
    }

    @Test func zeroIsNotABudget() {
        var draft = SubcategoryDraft(kind: .expense, group: .keinginan, monthlyBudget: 0)
        #expect(draft.monthlyBudget == nil)
        draft.monthlyBudget = 300_000
        #expect(draft.monthlyBudget == 300_000)
        draft.monthlyBudget = 0
        #expect(draft.monthlyBudget == nil, "saving 0 clears it (D-062)")
    }

    @Test func counterCountsTheTrimmedName() {
        var draft = SubcategoryDraft(kind: .expense, group: .kebutuhan)
        draft.name = "  Bakso "
        #expect(draft.nameLength == 5)
        #expect(draft.trimmedName == "Bakso")
        draft.name = "Pendidikanku"
        #expect(draft.nameLength == 12)
        #expect(draft.nameProblem(takenNames: taken) == .tooLong)
    }

    @Test func canSaveNeedsAValidEmojiAndAFreeName() {
        var draft = SubcategoryDraft(kind: .expense, group: .keinginan)
        draft.name = "Bakso"
        #expect(!draft.canSave(takenNames: taken), "no emoji yet")
        draft.setEmojiInput("🍜")
        #expect(draft.hasValidEmoji)
        #expect(draft.canSave(takenNames: taken))
        draft.name = "kopi"
        #expect(!draft.canSave(takenNames: taken), "the name is taken")
    }

    @Test(arguments: [
        ("🍜", "🍜"),
        ("🍜☕", "☕"),
        (" ☕ ", "☕"),
        ("🅿️", "🅿️"),
        ("", ""),
        ("  ", ""),
    ])
    func typingAnEmojiReplacesTheOldOne(input: String, expected: String) {
        var draft = SubcategoryDraft(kind: .expense, group: .kebutuhan, emoji: "🍚")
        draft.setEmojiInput(input)
        #expect(draft.emoji == expected)
    }

    @Test func textIsNotAnEmoji() {
        var draft = SubcategoryDraft(kind: .expense, group: .kebutuhan, name: "Bakso")
        draft.setEmojiInput("a")
        #expect(draft.emoji == "a")
        #expect(!draft.hasValidEmoji)
        #expect(!draft.canSave(takenNames: []))
    }

    /// Editing a subcategory: its own name doesn't count as taken, so the caller leaves it out.
    @Test func editingKeepsItsOwnName() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let kopi = try store.subcategory(named: "Kopi")
        let draft = SubcategoryDraft(kopi)
        #expect(draft.kind == .expense && draft.group == .keinginan)
        #expect(draft.name == "Kopi" && draft.emoji == "☕" && draft.monthlyBudget == nil)
        let others = try store.subcategories().filter { $0.id != kopi.id }.map(\.name)
        #expect(draft.canSave(takenNames: others))
        var renamed = draft
        renamed.name = "KOPI"
        #expect(renamed.canSave(takenNames: others), "changing only the case is allowed")
        renamed.name = "Jajan"
        #expect(renamed.nameProblem(takenNames: others) == .taken)
    }
}
