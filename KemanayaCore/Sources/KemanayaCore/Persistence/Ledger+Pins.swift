import Foundation
import SwiftData

/// Pin, unpin and reorder Home's cards (D-012, D-048, D-068), and hide or unhide a subcategory (D-049).
/// Same discipline as `Ledger+Writes.swift`: a refused write (``PinError``) changes nothing, and a
/// failed save puts every changed value back before rolling the context back.
///
/// Pins share one Home order; Home and Atur filter it per ``PinSection``, and each section has its own
/// limit (6 Kebutuhan, 6 Keinginan, 3 Pemasukan, D-068). Hiding always unpins (D-049), so every pin is
/// visible and counts toward its section's limit, and every write renumbers all pins `0..<n` in Home
/// order, so the order never has gaps or ties.
extension Ledger {
    /// Pins `subcategory` as the last card of its section. Pinning an already pinned one does nothing.
    /// - Throws: ``PinError/subcategoryHidden`` for a hidden subcategory, ``PinError/limitReached(_:)`` when
    ///   its section already holds ``PinSection/limit`` pins (D-068); otherwise the save error.
    public func pin(_ subcategory: Subcategory) throws {
        guard !subcategory.isHidden else { throw PinError.subcategoryHidden }
        let pinned = try pinnedSubcategories()
        guard !pinned.contains(where: { $0.id == subcategory.id }) else { return }
        let section = subcategory.pinSection
        guard pinned.count(where: { $0.pinSection == section }) < SubcategoryRules.maximumPins(in: section) else {
            throw PinError.limitReached(section)
        }
        try applyPinOrder(pinned + [subcategory])
    }

    /// Unpins `subcategory`; the cards after it move up. Unpinning one that isn't pinned does nothing.
    public func unpin(_ subcategory: Subcategory) throws {
        guard subcategory.isPinned else { return }
        let remaining = try pinnedSubcategories().filter { $0.id != subcategory.id }
        try applyPinOrder(remaining, unpinning: subcategory)
    }

    /// Moves the cards at `source` (offsets into ``pinnedSubcategories()``) to `destination`, with the
    /// same meaning as SwiftUI's `onMove`: `destination` is an offset in the list *before* the move.
    public func movePins(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        let pinned = try pinnedSubcategories()
        try applyPinOrder(PinOrder.moving(pinned, fromOffsets: source, toOffset: destination))
    }

    /// Moves pins within one Home section (D-068): `source` and `destination` are offsets into that
    /// section's pins, in Home order, with `onMove`'s meaning. The section's pins take the same places
    /// in the shared order, so the other sections keep their order.
    public func movePins(in section: PinSection, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        let pinned = try pinnedSubcategories()
        try applyPinOrder(PinOrder.moving(pinned, within: { $0.pinSection == section }, fromOffsets: source, toOffset: destination))
    }

    /// Hides `subcategory` (D-006): it leaves the add sheet and pin management. A pinned one is unpinned
    /// and the cards after it move up (D-049). Hiding an already hidden, unpinned one does nothing.
    /// Its transactions and budget stay. Settings (Phase 10) calls this.
    public func hide(_ subcategory: Subcategory) throws {
        let remaining = try pinnedSubcategories().filter { $0.id != subcategory.id }
        try applyPinOrder(remaining, unpinning: subcategory, hiding: true)
    }

    /// Shows `subcategory` again. It is not pinned again (D-049): pin it from Atur kartu if wanted.
    public func unhide(_ subcategory: Subcategory) throws {
        guard subcategory.isHidden else { return }
        subcategory.isHidden = false
        try saveOrRollBack { subcategory.isHidden = true }
    }

    /// Numbers `ordered` `0..<n`, clears `removed`'s pin (and hides it when `hiding`), then saves. On a
    /// failed save every changed value goes back, because `rollback()` doesn't revert attributes of
    /// saved models.
    private func applyPinOrder(_ ordered: [Subcategory], unpinning removed: Subcategory? = nil, hiding: Bool = false) throws {
        let affected = ordered + (removed.map { [$0] } ?? [])
        let old = affected.map { (subcategory: $0, pinOrder: $0.pinOrder, isHidden: $0.isHidden) }
        var changed = false
        for (index, subcategory) in ordered.enumerated() where subcategory.pinOrder != index {
            subcategory.pinOrder = index
            changed = true
        }
        if let removed, removed.pinOrder != nil {
            removed.pinOrder = nil
            changed = true
        }
        if hiding, let removed, !removed.isHidden {
            removed.isHidden = true
            changed = true
        }
        guard changed else { return }
        try saveOrRollBack {
            for entry in old {
                entry.subcategory.pinOrder = entry.pinOrder
                entry.subcategory.isHidden = entry.isHidden
            }
        }
    }
}

/// The arithmetic behind ``Ledger/movePins(fromOffsets:toOffset:)``, kept pure for tests.
enum PinOrder {
    /// `elements` with the items at `source` moved to `destination`, like SwiftUI's
    /// `MutableCollection.move(fromOffsets:toOffset:)` (which KemanayaCore can't import).
    /// Offsets outside `elements` are ignored; `destination` is clamped to `0...count`.
    static func moving<Element>(_ elements: [Element], fromOffsets source: IndexSet, toOffset destination: Int) -> [Element] {
        let valid = source.filter { elements.indices.contains($0) }
        guard !valid.isEmpty else { return elements }
        let target = min(max(destination, 0), elements.count)
        let moving = valid.map { elements[$0] }
        var rest = elements.enumerated().filter { !valid.contains($0.offset) }.map(\.element)
        let insertion = target - valid.filter { $0 < target }.count
        rest.insert(contentsOf: moving, at: insertion)
        return rest
    }

    /// `elements` with only the members matching `isMember` reordered by ``moving(_:fromOffsets:toOffset:)``
    /// (offsets into the members), each member taking a former member's place, so the others stay put.
    static func moving<Element>(
        _ elements: [Element],
        within isMember: (Element) -> Bool,
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) -> [Element] {
        let slots = elements.indices.filter { isMember(elements[$0]) }
        let reordered = moving(slots.map { elements[$0] }, fromOffsets: source, toOffset: destination)
        var result = elements
        for (slot, element) in zip(slots, reordered) {
            result[slot] = element
        }
        return result
    }
}
