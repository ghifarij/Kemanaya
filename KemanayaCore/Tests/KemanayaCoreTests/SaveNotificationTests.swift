import Foundation
@testable import KemanayaCore
import SwiftData
import Testing

/// The automatic backup (D-060) is triggered by `ModelContext.didSave`. These pin down that SwiftData
/// posts it for the app's kinds of saves on the main context, on every supported OS version.
@MainActor
struct SaveNotificationTests {
    /// Counts the notifications posted while it lives.
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func increment() { lock.withLock { count += 1 } }
        var value: Int { lock.withLock { count } }
    }

    /// Only `context`'s saves count, so tests running in parallel don't.
    private func counting(_ context: ModelContext, _ body: () throws -> Void) rethrows -> Int {
        let counter = Counter()
        let observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: context, queue: nil) { _ in
            counter.increment()
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        try body()
        return counter.value
    }

    @Test func seedingAddsAndRestoresPostDidSave() throws {
        let container = try TestStore.containerCreation.withLock { try KemanayaStore.makeContainer(inMemory: true) }
        let context = container.mainContext
        #expect(try counting(context) { try Seeder.seedIfNeeded(in: context) } >= 1, "seeding")

        let ledger = Ledger(context: context, timeZone: Fixtures.jakarta)
        let makan = try #require(try context.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == "Makan" })).first)
        #expect(try counting(context) {
            try ledger.addTransaction(amount: 10_000, subcategory: makan, date: .now, note: nil)
        } >= 1, "an add")

        let document = try Backup.snapshot(of: context, appVersion: "1.0")
        #expect(try counting(context) { try Backup.restore(document, into: context) } >= 1, "a restore")
        #expect(try counting(context) { _ = try Backup.snapshot(of: context, appVersion: "1.0") } == 0, "a snapshot only reads")
    }
}
