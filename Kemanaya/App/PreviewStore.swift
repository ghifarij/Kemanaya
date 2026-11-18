import Foundation
import KemanayaCore
import SwiftData

#if DEBUG
/// Throwaway stores for SwiftUI previews: in memory, seeded, with a few sample transactions.
/// Never used by the running app.
enum PreviewStore {
    /// - Parameter withSamples: false for an empty month (the list's empty state).
    static func makeContainer(withSamples: Bool = true) -> ModelContainer {
        do {
            let container = try KemanayaStore.makeContainer(inMemory: true)
            let context = container.mainContext
            try Seeder.seedIfNeeded(in: context)
            if withSamples {
                let ledger = Ledger(context: context, timeZone: .autoupdatingCurrent)
                let samples: [(Int64, String, String?)] = [
                    (8_500_000, "Gaji", nil),
                    (30_000, "Makan", "Nasi padang"),
                    (18_000, "Kopi", nil),
                ]
                for (amount, name, note) in samples {
                    let subcategory = try context.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == name })).first
                    if let subcategory {
                        try ledger.addTransaction(amount: amount, subcategory: subcategory, date: .now, note: note)
                    }
                }
            }
            return container
        } catch {
            fatalError("Preview store failed: \(error)")
        }
    }
}
#endif
