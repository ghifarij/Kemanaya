import Foundation
@testable import KemanayaCore
import SwiftData
import Testing

/// Pin, unpin and reorder Home's cards, and hide or unhide, through ``Ledger`` (D-012, D-048, D-049).
struct LedgerPinTests {
    /// The seed pins Makan, Kopi, Jajan, Parkir, Galon, Hiburan (D-012).
    private static let defaultPins = ["Makan", "Kopi", "Jajan", "Parkir", "Galon", "Hiburan"]

    private func makeStore() throws -> (TestStore, Ledger) {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        return (store, Ledger(context: store.context, timeZone: Fixtures.jakarta))
    }

    /// Pinned names as saved, read through a fresh context.
    private func savedPins(_ store: TestStore) throws -> [String] {
        try Ledger(context: ModelContext(store.container), timeZone: Fixtures.jakarta).pinnedSubcategories().map(\.name)
    }

    /// All pins are numbered 0..<n with no gaps or ties, and none is hidden (D-049).
    private func expectDensePinOrder(_ store: TestStore, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let fresh = ModelContext(store.container)
        let pins = try fresh.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.pinOrder != nil }))
        let orders = pins.compactMap(\.pinOrder).sorted()
        let hidden = pins.filter(\.isHidden).map(\.name)
        #expect(orders == Array(0..<pins.count), sourceLocation: sourceLocation)
        #expect(hidden.isEmpty, sourceLocation: sourceLocation)
    }

    // MARK: - Pin

    @Test func pinAddsTheCardLast() throws {
        let (store, ledger) = try makeStore()
        try ledger.pin(try store.subcategory(named: "Gaji"))
        #expect(!store.context.hasChanges, "pin saves")
        #expect(try savedPins(store) == Self.defaultPins + ["Gaji"], "income can be pinned too")
        try expectDensePinOrder(store)
    }

    @Test func pinningAPinnedSubcategoryChangesNothing() throws {
        let (store, ledger) = try makeStore()
        try ledger.pin(try store.subcategory(named: "Kopi"))
        #expect(try savedPins(store) == Self.defaultPins)
    }

    /// Nine is the limit; the tenth is refused and nothing changes (D-012, D-048).
    @Test func aTenthPinIsRefused() throws {
        let (store, ledger) = try makeStore()
        for name in ["Dapur", "Gas", "Gaji"] {
            try ledger.pin(try store.subcategory(named: name))
        }
        #expect(try ledger.pinnedSubcategories().count == SubcategoryRules.maximumPins)
        let listrik = try store.subcategory(named: "Listrik")
        #expect(throws: PinError.limitReached) { try ledger.pin(listrik) }
        #expect(listrik.pinOrder == nil)
        #expect(!store.context.hasChanges)
        #expect(try savedPins(store) == Self.defaultPins + ["Dapur", "Gas", "Gaji"])
    }

    @Test func hiddenSubcategoriesCantBePinned() throws {
        let (store, ledger) = try makeStore()
        let dapur = try store.subcategory(named: "Dapur")
        dapur.isHidden = true
        try store.context.save()
        #expect(throws: PinError.subcategoryHidden) { try ledger.pin(dapur) }
        #expect(dapur.pinOrder == nil)
    }

    /// Every pin counts toward the nine; hiding one frees its place (D-049).
    @Test func hidingAPinFreesItsPlace() throws {
        let (store, ledger) = try makeStore()
        for name in ["Dapur", "Gas", "Gaji"] {
            try ledger.pin(try store.subcategory(named: name))
        }
        let air = try store.subcategory(named: "Air")
        #expect(throws: PinError.limitReached) { try ledger.pin(air) }
        try ledger.hide(try store.subcategory(named: "Jajan"))
        try ledger.pin(air)
        #expect(try savedPins(store) == ["Makan", "Kopi", "Parkir", "Galon", "Hiburan", "Dapur", "Gas", "Gaji", "Air"])
        try expectDensePinOrder(store)
    }

    // MARK: - Unpin

    @Test func unpinClosesTheGap() throws {
        let (store, ledger) = try makeStore()
        let jajan = try store.subcategory(named: "Jajan")
        try ledger.unpin(jajan)
        #expect(jajan.pinOrder == nil)
        #expect(!store.context.hasChanges)
        #expect(try savedPins(store) == ["Makan", "Kopi", "Parkir", "Galon", "Hiburan"])
        try expectDensePinOrder(store)
    }

    @Test func unpinningAnUnpinnedSubcategoryChangesNothing() throws {
        let (store, ledger) = try makeStore()
        try ledger.unpin(try store.subcategory(named: "Dapur"))
        #expect(try savedPins(store) == Self.defaultPins)
    }

    @Test func unpinningEverythingLeavesNoCards() throws {
        let (store, ledger) = try makeStore()
        for subcategory in try ledger.pinnedSubcategories() {
            try ledger.unpin(subcategory)
        }
        #expect(try savedPins(store).isEmpty)
    }

    /// After an unpin there is room for a new ninth pin again.
    @Test func unpinMakesRoomAgain() throws {
        let (store, ledger) = try makeStore()
        for name in ["Dapur", "Gas", "Gaji"] {
            try ledger.pin(try store.subcategory(named: name))
        }
        try ledger.unpin(try store.subcategory(named: "Makan"))
        try ledger.pin(try store.subcategory(named: "Listrik"))
        #expect(try savedPins(store) == ["Kopi", "Jajan", "Parkir", "Galon", "Hiburan", "Dapur", "Gas", "Gaji", "Listrik"])
    }

    // MARK: - Hide (D-049)

    @Test func hidingAPinnedSubcategoryUnpinsIt() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try ledger.hide(kopi)
        #expect(kopi.isHidden)
        #expect(kopi.pinOrder == nil)
        #expect(!store.context.hasChanges, "hide saves")
        #expect(try savedPins(store) == ["Makan", "Jajan", "Parkir", "Galon", "Hiburan"])
        try expectDensePinOrder(store)
    }

    @Test func hidingAnUnpinnedSubcategoryKeepsThePins() throws {
        let (store, ledger) = try makeStore()
        let dapur = try store.subcategory(named: "Dapur")
        try ledger.hide(dapur)
        #expect(dapur.isHidden)
        #expect(!store.context.hasChanges)
        #expect(try savedPins(store) == Self.defaultPins)
        try expectDensePinOrder(store)
    }

    @Test func hidingTwiceChangesNothing() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try ledger.hide(kopi)
        try ledger.hide(kopi)
        #expect(kopi.isHidden)
        #expect(try savedPins(store) == ["Makan", "Jajan", "Parkir", "Galon", "Hiburan"])
    }

    @Test func unhidingDoesntPinAgain() throws {
        let (store, ledger) = try makeStore()
        let kopi = try store.subcategory(named: "Kopi")
        try ledger.hide(kopi)
        try ledger.unhide(kopi)
        #expect(!kopi.isHidden)
        #expect(kopi.pinOrder == nil)
        #expect(!store.context.hasChanges, "unhide saves")
        #expect(try savedPins(store) == ["Makan", "Jajan", "Parkir", "Galon", "Hiburan"])
        try expectDensePinOrder(store)
    }

    // MARK: - Reorder

    @Test func moveDownFollowsOnMoveSemantics() throws {
        let (store, ledger) = try makeStore()
        // Makan (0) dropped before Galon (4): it lands after Parkir.
        try ledger.movePins(fromOffsets: [0], toOffset: 4)
        #expect(try savedPins(store) == ["Kopi", "Jajan", "Parkir", "Makan", "Galon", "Hiburan"])
        try expectDensePinOrder(store)
    }

    @Test func moveUpAndToTheEnd() throws {
        let (store, ledger) = try makeStore()
        try ledger.movePins(fromOffsets: [5], toOffset: 0)
        #expect(try savedPins(store) == ["Hiburan", "Makan", "Kopi", "Jajan", "Parkir", "Galon"])
        try ledger.movePins(fromOffsets: [0], toOffset: 6)
        #expect(try savedPins(store) == Self.defaultPins)
    }

    @Test func movingInPlaceSavesNothing() throws {
        let (store, ledger) = try makeStore()
        try ledger.movePins(fromOffsets: [2], toOffset: 2)
        try ledger.movePins(fromOffsets: [2], toOffset: 3)
        #expect(!store.context.hasChanges)
        #expect(try savedPins(store) == Self.defaultPins)
    }

    // MARK: - Failed saves roll back

    private struct SaveFailed: Error {}

    private func failingLedger(_ store: TestStore) -> Ledger {
        Ledger(context: store.context, timeZone: Fixtures.jakarta) { _ in throw SaveFailed() }
    }

    @Test func failedPinRestoresTheOrder() throws {
        let (store, _) = try makeStore()
        let gaji = try store.subcategory(named: "Gaji")
        #expect(throws: SaveFailed.self) { try failingLedger(store).pin(gaji) }
        #expect(gaji.pinOrder == nil)
        #expect(!store.context.hasChanges)
        #expect(try Ledger(context: store.context, timeZone: Fixtures.jakarta).pinnedSubcategories().map(\.name) == Self.defaultPins)
    }

    @Test func failedUnpinRestoresEveryPin() throws {
        let (store, _) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        #expect(throws: SaveFailed.self) { try failingLedger(store).unpin(makan) }
        #expect(makan.pinOrder == 0)
        #expect(!store.context.hasChanges)
        let inMemory = try Ledger(context: store.context, timeZone: Fixtures.jakarta).pinnedSubcategories()
        #expect(inMemory.map(\.name) == Self.defaultPins)
        #expect(inMemory.compactMap(\.pinOrder) == Array(0..<6), "the renumbered pins went back too")
    }

    @Test func failedMoveRestoresTheOrder() throws {
        let (store, _) = try makeStore()
        #expect(throws: SaveFailed.self) { try failingLedger(store).movePins(fromOffsets: [0], toOffset: 6) }
        #expect(!store.context.hasChanges)
        #expect(try Ledger(context: store.context, timeZone: Fixtures.jakarta).pinnedSubcategories().map(\.name) == Self.defaultPins)
    }

    @Test func failedHideRestoresVisibilityAndEveryPin() throws {
        let (store, _) = try makeStore()
        let makan = try store.subcategory(named: "Makan")
        #expect(throws: SaveFailed.self) { try failingLedger(store).hide(makan) }
        #expect(!makan.isHidden)
        #expect(makan.pinOrder == 0)
        #expect(!store.context.hasChanges)
        let inMemory = try Ledger(context: store.context, timeZone: Fixtures.jakarta).pinnedSubcategories()
        #expect(inMemory.map(\.name) == Self.defaultPins)
        #expect(inMemory.compactMap(\.pinOrder) == Array(0..<6), "the renumbered pins went back too")
    }

    @Test func failedUnhideKeepsItHidden() throws {
        let (store, ledger) = try makeStore()
        let dapur = try store.subcategory(named: "Dapur")
        try ledger.hide(dapur)
        #expect(throws: SaveFailed.self) { try failingLedger(store).unhide(dapur) }
        #expect(dapur.isHidden)
        #expect(!store.context.hasChanges)
    }

    // MARK: - PinOrder.moving

    @Test(arguments: [
        (IndexSet([0]), 2, ["b", "a", "c", "d"]),
        (IndexSet([0]), 4, ["b", "c", "d", "a"]),
        (IndexSet([3]), 0, ["d", "a", "b", "c"]),
        (IndexSet([1, 2]), 4, ["a", "d", "b", "c"]),
        (IndexSet([0, 3]), 2, ["b", "a", "d", "c"]),
        (IndexSet([1]), 1, ["a", "b", "c", "d"]),
        (IndexSet([1]), 99, ["a", "c", "d", "b"]),
        (IndexSet([7]), 0, ["a", "b", "c", "d"]),
    ])
    func movingMatchesOnMove(source: IndexSet, destination: Int, expected: [String]) {
        #expect(PinOrder.moving(["a", "b", "c", "d"], fromOffsets: source, toOffset: destination) == expected)
    }
}
