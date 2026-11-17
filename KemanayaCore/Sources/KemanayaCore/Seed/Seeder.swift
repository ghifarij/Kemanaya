import Foundation
import SwiftData

/// Inserts the seed (``SeedData``) once per store. Safe to call on every launch.
public enum Seeder {
    /// Seeds the store if this seed version hasn't been applied, then saves.
    ///
    /// Only an empty store gets the subcategories: once the user has any (seeded, restored or
    /// self-made), nothing is inserted, renamed, re-pinned or un-hidden. The applied version is
    /// recorded in ``AppSettings/seedVersion``, so later calls do nothing.
    /// - Returns: true when subcategories were inserted.
    @discardableResult
    public static func seedIfNeeded(in context: ModelContext, now: Date = .now) throws -> Bool {
        let settings = try AppSettings.fetchOrCreate(in: context)
        guard settings.seedVersion < SeedData.version else {
            if context.hasChanges { try context.save() }
            return false
        }

        let isEmpty = try context.fetchCount(FetchDescriptor<Subcategory>()) == 0
        if isEmpty {
            for section in SeedData.sections {
                for (index, entry) in section.enumerated() {
                    let pin = entry.kind == .expense ? SeedData.defaultPins.firstIndex(of: entry.name) : nil
                    context.insert(Subcategory(
                        id: entry.id,
                        name: entry.name,
                        emoji: entry.emoji,
                        kind: entry.kind,
                        group: entry.group,
                        sortOrder: index,
                        pinOrder: pin,
                        createdAt: now
                    ))
                }
            }
        }
        settings.seedVersion = SeedData.version
        try context.save()
        return isEmpty
    }
}
