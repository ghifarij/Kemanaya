import Foundation
@testable import KemanayaCore
import SwiftData
import Testing

struct StoreTests {
    /// Data written to an on-disk store survives closing and reopening it through the schema and migration plan.
    @Test func onDiskStoreRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "KemanayaStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "test.store")

        let transactionID = try {
            let container = try TestStore.containerCreation.withLock { try KemanayaStore.makeContainer(storeURL: url) }
            let context = ModelContext(container)
            try Seeder.seedIfNeeded(in: context)
            let kopi = try #require(try context.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == "Kopi" })).first)
            let transaction = MoneyTransaction(amount: 25_000, subcategory: kopi, date: Fixtures.date(2026, 11, 17))
            context.insert(transaction)
            try context.save()
            return transaction.id
        }() // The container is released here.

        let reopened = try TestStore.containerCreation.withLock { try KemanayaStore.makeContainer(storeURL: url) }
        let context = ModelContext(reopened)
        #expect(try context.fetchCount(FetchDescriptor<Subcategory>()) == 44)
        #expect(try context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
        let transactions = try context.fetch(FetchDescriptor<MoneyTransaction>())
        #expect(transactions.map(\.id) == [transactionID])
        #expect(transactions.first?.subcategory?.name == "Kopi")
        #expect(try !Seeder.seedIfNeeded(in: context))
    }
}
