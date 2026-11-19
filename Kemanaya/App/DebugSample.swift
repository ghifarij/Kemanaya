#if DEBUG
import Foundation
import KemanayaCore
import SwiftData

/// Sample data for UI tests and screenshots (D-048): `-debugSample budgets | transactions | full`.
/// Budgets can't be set in the app before Settings (Phase 10), so this is how Home's budget UI is reached.
///
/// Debug builds only, and only with `-inMemoryStore`, so it can never touch real data.
/// `UserDefaults` reads `-key value` launch arguments, as `-gallerySection` does.
enum DebugSample: String {
    /// Group budgets and a few subcategory budgets, no transactions.
    case budgets
    /// Transactions this month and last month, no budgets.
    case transactions
    /// Both.
    case full

    /// The sample named by `-debugSample`, if any.
    static var fromLaunchArguments: DebugSample? {
        UserDefaults.standard.string(forKey: "debugSample").flatMap(DebugSample.init(rawValue:))
    }

    /// Adds the sample to a freshly seeded store and saves.
    func apply(to context: ModelContext, now: Date = .now) throws {
        if self != .transactions { try addBudgets(context) }
        if self != .budgets { try addTransactions(context, now: now) }
    }

    private func addBudgets(_ context: ModelContext) throws {
        let settings = try AppSettings.fetchOrCreate(in: context)
        settings.setBudget(3_000_000, for: .kebutuhan)
        settings.setBudget(500_000, for: .keinginan)
        // Kopi stays under its budget and Jajan goes over, so both captions are on screen; Makan has none.
        try subcategory("Kopi", context).setMonthlyBudget(300_000)
        try subcategory("Jajan", context).setMonthlyBudget(150_000)
        try subcategory("Parkir", context).setMonthlyBudget(100_000)
        try context.save()
    }

    private func addTransactions(_ context: ModelContext, now: Date) throws {
        let timeZone = TimeZone.autoupdatingCurrent
        let ledger = Ledger(context: context, timeZone: timeZone)
        let month = MonthKey(containing: now, timeZone: timeZone)
        // This month: a minute apart going back from now, never before the month's start, so every date is valid.
        let thisMonth: [(String, Int64)] = [
            ("Gaji", 8_500_000), ("Makan", 750_000), ("Makan", 500_000), ("Kopi", 245_000),
            ("Jajan", 186_500), ("Parkir", 54_000), ("Galon", 40_000),
        ]
        let start = month.start(in: timeZone)
        for (index, entry) in thisMonth.enumerated() {
            let date = max(start, now.addingTimeInterval(-60 * Double(index + 1)))
            try ledger.addTransaction(amount: entry.1, subcategory: subcategory(entry.0, context), date: date, note: nil, now: now)
        }
        // Last month, so the cards' tiny bars have something to compare with. Hiburan only last month.
        let lastMonth: [(String, Int64)] = [
            ("Gaji", 8_500_000), ("Makan", 1_410_000), ("Kopi", 280_000), ("Jajan", 186_500),
            ("Parkir", 61_000), ("Galon", 20_000), ("Hiburan", 150_000),
        ]
        let lastStart = month.previous.start(in: timeZone)
        for (index, entry) in lastMonth.enumerated() {
            let date = lastStart.addingTimeInterval(86_400 * Double(index + 1))
            try ledger.addTransaction(amount: entry.1, subcategory: subcategory(entry.0, context), date: date, note: nil, now: now)
        }
    }

    private func subcategory(_ name: String, _ context: ModelContext) throws -> Subcategory {
        let descriptor = FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == name })
        guard let match = try context.fetch(descriptor).first else { throw MissingSubcategory(name: name) }
        return match
    }

    private struct MissingSubcategory: Error {
        let name: String
    }
}
#endif
