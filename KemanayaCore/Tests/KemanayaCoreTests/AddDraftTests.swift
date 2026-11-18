import Foundation
@testable import KemanayaCore
import Testing

/// The add / edit sheet's rules (D-013, D-043, D-044).
struct AddDraftTests {
    private let now = Fixtures.date(2026, 11, 18, 10, 30)
    private let makan = AddDraft.Pick(id: UUID(), kind: .expense)
    private let kopi = AddDraft.Pick(id: UUID(), kind: .expense)
    private let gaji = AddDraft.Pick(id: UUID(), kind: .income)

    private func typed(_ draft: AddDraft, _ keys: KeypadInput...) -> AddDraft {
        var copy = draft
        for key in keys { copy.entry.press(key) }
        return copy
    }

    private func tapping(_ pick: AddDraft.Pick, on draft: AddDraft) -> (outcome: AddDraft.TapOutcome, draft: AddDraft) {
        var copy = draft
        let outcome = copy.tap(pick)
        return (outcome, copy)
    }

    // MARK: - Add mode

    @Test func addStartsEmptyOnExpenses() {
        let draft = AddDraft.add(now: now)
        #expect(draft.kind == .expense)
        #expect(draft.entry.isEmpty)
        #expect(draft.selection == nil)
        #expect(draft.note.isEmpty)
        #expect(!draft.savesWithButton)
        #expect(draft.includedHiddenSubcategoryID == nil)
    }

    @Test func addTilesAreDisabledUntilThereIsAnAmount() {
        let empty = AddDraft.add(now: now)
        #expect(empty.tilesDisabled)
        #expect(tapping(makan, on: empty).outcome == .ignored)
        #expect(!empty.tapSaves(makan))

        let typed = typed(empty, .digit(2), .digit(5), .tripleZero)
        #expect(!typed.tilesDisabled)
        #expect(typed.tapSaves(makan))
        #expect(tapping(makan, on: typed).outcome == .save(makan.id), "the third tap saves (D-013)")
    }

    @Test func switchingKindKeepsTheAmount() {
        var draft = typed(.add(now: now), .digit(5), .tripleZero, .tripleZero)
        draft.kind = .income
        #expect(draft.entry.amount == 5_000_000)
        #expect(tapping(gaji, on: draft).outcome == .save(gaji.id))
    }

    // MARK: - Preselected mode (Phase 5 pinned cards)

    @Test func preselectedHighlightsTheSubcategoryAndUsesItsKind() {
        let draft = AddDraft.preselected(gaji, isHidden: false, now: now)
        #expect(draft.kind == .income)
        #expect(draft.selectedOfCurrentKind == gaji)
        #expect(draft.savesWithButton)
        #expect(!draft.tilesDisabled, "selecting needs no amount")
        #expect(!draft.canSave, "but saving does")
        #expect(draft.includedHiddenSubcategoryID == nil)
    }

    /// A hidden subcategory can't take new entries (D-006), so it is never preselected.
    @Test func aHiddenSubcategoryIsNotPreselected() {
        let draft = AddDraft.preselected(kopi, isHidden: true, now: now)
        #expect(draft.selection == nil)
        #expect(draft.kind == .expense)
        #expect(draft.includedHiddenSubcategoryID == nil)
    }

    @Test func tappingAnotherTileOnlySelectsIt() {
        let draft = typed(.preselected(makan, isHidden: false, now: now), .digit(9))
        let (outcome, after) = tapping(kopi, on: draft)
        #expect(outcome == .selected)
        #expect(after.selectedOfCurrentKind == kopi)
        #expect(!after.tapSaves(makan))
        #expect(after.tapSaves(kopi))
    }

    /// D-044: tapping the highlighted tile saves, the same as Simpan.
    @Test func tappingTheHighlightedTileSaves() {
        let empty = AddDraft.preselected(makan, isHidden: false, now: now)
        #expect(tapping(makan, on: empty).outcome == .selected, "no amount yet: nothing to save")

        let draft = typed(empty, .digit(9), .tripleZero)
        #expect(draft.canSave)
        #expect(draft.tapSaves(makan))
        #expect(tapping(makan, on: draft).outcome == .save(makan.id))
    }

    /// The selection is remembered across kind switches but only counts for its own kind.
    @Test func switchingKindRemembersTheSelection() {
        var draft = typed(.preselected(makan, isHidden: false, now: now), .digit(4))
        draft.kind = .income
        #expect(draft.selectedOfCurrentKind == nil)
        #expect(!draft.canSave)
        #expect(draft.entry.amount == 4)
        draft.kind = .expense
        #expect(draft.selectedOfCurrentKind == makan)
        #expect(draft.canSave)
    }

    // MARK: - Edit mode

    @Test func editPrefillsEverything() {
        let date = Fixtures.date(2026, 11, 3, 19)
        let draft = AddDraft.edit(amount: 30_000, kind: .expense, subcategory: makan, date: date, note: "siang")
        #expect(draft.entry.amount == 30_000)
        #expect(draft.kind == .expense)
        #expect(draft.selectedOfCurrentKind == makan)
        #expect(draft.note == "siang")
        #expect(draft.date == date)
        #expect(draft.originalDate == date)
        #expect(draft.canSave)
        #expect(draft.savesWithButton)
        #expect(draft.includedHiddenSubcategoryID == makan.id, "the grid keeps the edited transaction's own subcategory")
    }

    @Test func editOfAnOrphanNeedsAPick() {
        let draft = AddDraft.edit(amount: 30_000, kind: .expense, subcategory: nil, date: now, note: nil)
        #expect(!draft.canSave)
        #expect(draft.includedHiddenSubcategoryID == nil)
        let (outcome, after) = tapping(kopi, on: draft)
        #expect(outcome == .selected)
        #expect(after.canSave)
    }

    // MARK: - Dates (D-044)

    @Test func untouchedNewEntryIsDatedWhenSaved() {
        let draft = AddDraft.add(now: now)
        let later = now.addingTimeInterval(90)
        #expect(draft.dateToSave(now: later, timeZone: Fixtures.jakarta) == later, "not when the sheet opened")
    }

    @Test func untouchedEditKeepsItsDate() {
        let date = Fixtures.date(2026, 11, 3, 19, 15)
        let draft = AddDraft.edit(amount: 1, kind: .expense, subcategory: makan, date: date, note: nil)
        #expect(draft.dateToSave(now: now, timeZone: Fixtures.jakarta) == date)
    }

    /// A transaction dated after this month (e.g. recorded in a time zone ahead) keeps its exact date
    /// when the date isn't touched.
    @Test func untouchedEditKeepsADateAfterThisMonth() {
        let date = Fixtures.date(2026, 12, 1, 6, 30)
        let draft = AddDraft.edit(amount: 1, kind: .expense, subcategory: makan, date: date, note: nil)
        #expect(draft.dateToSave(now: now, timeZone: Fixtures.jakarta) == date)
    }

    @Test func untouchedEditKeepsADateOlderThanTheWindow() {
        let date = Fixtures.date(2025, 10, 20, 8)
        let draft = AddDraft.edit(amount: 1, kind: .expense, subcategory: makan, date: date, note: nil)
        #expect(draft.dateToSave(now: now, timeZone: Fixtures.jakarta) == date)
    }

    @Test func aPickedDayGetsTheTimeOfDayOfSaving() {
        var draft = AddDraft.add(now: now)
        // A picker keeps the open-time's time of day; only the day counts.
        draft.setDate(Fixtures.date(2026, 11, 25, 10, 30))
        #expect(draft.isDateChanged)
        let saveTime = Fixtures.date(2026, 11, 18, 10, 45, 7)
        #expect(draft.dateToSave(now: saveTime, timeZone: Fixtures.jakarta) == Fixtures.date(2026, 11, 25, 10, 45, 7))

        draft.setDate(Fixtures.date(2026, 11, 2, 10, 30))
        #expect(draft.dateToSave(now: saveTime, timeZone: Fixtures.jakarta) == Fixtures.date(2026, 11, 2, 10, 45, 7))
    }

    @Test func anEditMovedToAnotherDayKeepsItsTimeOfDay() {
        var draft = AddDraft.edit(amount: 1, kind: .expense, subcategory: makan, date: Fixtures.date(2026, 11, 3, 19, 15), note: nil)
        draft.setDate(Fixtures.date(2026, 11, 5, 19, 15))
        #expect(draft.dateToSave(now: now, timeZone: Fixtures.jakarta) == Fixtures.date(2026, 11, 5, 19, 15))
    }

    @Test func settingTheSameDateIsNotAChange() {
        var draft = AddDraft.add(now: now)
        draft.setDate(now)
        #expect(!draft.isDateChanged)
    }

    @Test func aPickedDayIsClampedIntoThisMonth() {
        var draft = AddDraft.add(now: now)
        draft.setDate(Fixtures.date(2026, 12, 5))
        let saved = draft.dateToSave(now: now, timeZone: Fixtures.jakarta)
        #expect(saved < Fixtures.date(2026, 12, 1, 0))
        #expect(saved > Fixtures.date(2026, 11, 30, 23, 59, 59))
    }

    @Test func dayAtTimeCombinesInTheTimeZone() {
        let combined = AddDraft.day(of: Fixtures.date(2026, 11, 25, 1), atTimeOf: Fixtures.date(2026, 11, 18, 23, 59, 30), in: Fixtures.jakarta)
        #expect(combined == Fixtures.date(2026, 11, 25, 23, 59, 30))
    }
}
