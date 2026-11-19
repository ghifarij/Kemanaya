import Foundation
import KemanayaCore
import SwiftData
import Testing

/// The fetches Analisis and the subcategory detail make (D-018, D-051).
struct AnalysisLedgerTests {
    private let november = MonthKey(year: 2026, month: 11)

    @Test func subcategoryFilterFetchesOneSubcategoryInTheMonth() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let kopi = try store.subcategory(named: "Kopi")
        let makan = try store.subcategory(named: "Makan")
        for (amount, subcategory, date) in [
            (18_000, kopi, Fixtures.date(2026, 11, 3)),
            (25_000, kopi, Fixtures.date(2026, 11, 20)),
            (50_000, makan, Fixtures.date(2026, 11, 4)),
            (40_000, kopi, Fixtures.date(2026, 10, 31, 23, 59, 59)),
        ] as [(Int64, Subcategory, Date)] {
            store.context.insert(MoneyTransaction(amount: amount, subcategory: subcategory, date: date))
        }
        try store.context.save()
        let ledger = Ledger(context: store.context, timeZone: Fixtures.jakarta)
        #expect(try ledger.transactions(in: november, filter: .subcategory(kopi.id)).map(\.amount) == [25_000, 18_000])
        #expect(try ledger.transactions(in: november.previous, filter: .subcategory(kopi.id)).map(\.amount) == [40_000])
        #expect(try ledger.transactions(in: november, filter: .subcategory(UUID())).isEmpty)
    }

    /// The six-month fetch range feeds the series without a month too many or too few.
    @Test func seriesRangeFetch() throws {
        let store = try TestStore()
        try Seeder.seedIfNeeded(in: store.context)
        let makan = try store.subcategory(named: "Makan")
        let gaji = try store.subcategory(named: "Gaji")
        for (amount, subcategory, date) in [
            (1_000, makan, Fixtures.date(2026, 5, 31, 23, 59, 59)),
            (2_000, makan, Fixtures.date(2026, 6, 1, 0)),
            (3_000, gaji, Fixtures.date(2026, 11, 30, 23, 59, 59)),
            (4_000, makan, Fixtures.date(2026, 12, 1, 0)),
        ] as [(Int64, Subcategory, Date)] {
            store.context.insert(MoneyTransaction(amount: amount, subcategory: subcategory, date: date))
        }
        try store.context.save()
        let range = MonthlyFlowSeries.dateRange(ending: november, timeZone: Fixtures.jakarta)
        let fetched = try store.context.fetch(MoneyTransaction.descriptor(in: range)).map(TransactionSnapshot.init)
        #expect(fetched.map(\.amount).sorted() == [2_000, 3_000])
        let series = MonthlyFlowSeries(fetched, ending: november, timeZone: Fixtures.jakarta)
        #expect(series.months.first?.expenses == 2_000)
        #expect(series.months.last?.income == 3_000)
    }
}
