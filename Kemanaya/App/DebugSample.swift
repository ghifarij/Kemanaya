#if DEBUG
import Foundation
import KemanayaCore
import SwiftData

/// Sample data for UI tests and screenshots (D-048, D-051): `-debugSample budgets | transactions | full`.
/// Budgets can't be set in the app before Settings (Phase 10), so this is how Home's budget UI is reached.
///
/// Debug builds only, and only with `-inMemoryStore`, so it can never touch real data.
/// `UserDefaults` reads `-key value` launch arguments, as `-gallerySection` does.
enum DebugSample: String {
    /// Group budgets and a few subcategory budgets, no transactions.
    case budgets
    /// Transactions this month, last month and two to five months back, no budgets.
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
        // This month: spread evenly from the month's start up to a minute before now, so every date is
        // valid and Analisis's daily chart has several bars (D-051).
        let thisMonth: [(String, Int64)] = [
            ("Gaji", 8_500_000), ("Makan", 750_000), ("Makan", 500_000), ("Kopi", 245_000),
            ("Jajan", 186_500), ("Parkir", 54_000), ("Galon", 40_000),
        ]
        let start = month.start(in: timeZone)
        let span = max(now.addingTimeInterval(-60).timeIntervalSince(start), 0)
        for (index, entry) in thisMonth.enumerated() {
            let date = start.addingTimeInterval(span * Double(index) / Double(thisMonth.count - 1))
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
        // Two to five months back: income and a little spending, so Analisis's six-month chart is filled.
        for monthsBack in 2...5 {
            let monthStart = month.adding(months: -monthsBack).start(in: timeZone)
            let older: [(String, Int64)] = [
                ("Gaji", 8_500_000), ("Makan", 1_200_000 + Int64(monthsBack) * 50_000), ("Kopi", 200_000), ("Nongkrong", 350_000),
            ]
            for (index, entry) in older.enumerated() {
                let date = monthStart.addingTimeInterval(86_400 * Double(index * 5 + 1))
                try ledger.addTransaction(amount: entry.1, subcategory: subcategory(entry.0, context), date: date, note: nil, now: now)
            }
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
