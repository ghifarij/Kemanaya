import Foundation
import KemanayaCore
import SwiftData

/// Shared fixtures for the core tests.
enum Fixtures {
    static let jakarta = TimeZone(identifier: "Asia/Jakarta")!
    static let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    /// A date from local wall-clock components in `timeZone` (Gregorian).
    static func date(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0,
        in timeZone: TimeZone = jakarta
    ) -> Date {
        Calendar.gregorian(in: timeZone)
            .date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }
}

/// A fresh in-memory store and a context on it. Keeps the container alive for the test's duration.
/// Each store has its own uniquely named container, so tests using it can run in parallel.
struct TestStore {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try KemanayaStore.makeContainer(inMemory: true)
        context = ModelContext(container)
    }

    /// Every subcategory in a deterministic order: kind, group, sort order, then name.
    func subcategories() throws -> [Subcategory] {
        try context.fetch(FetchDescriptor<Subcategory>()).sorted {
            ($0.kindRaw, $0.groupRaw ?? "", $0.sortOrder, $0.name) < ($1.kindRaw, $1.groupRaw ?? "", $1.sortOrder, $1.name)
        }
    }

    /// The subcategory named `name`.
    func subcategory(named name: String) throws -> Subcategory {
        let descriptor = FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == name })
        guard let match = try context.fetch(descriptor).first else { throw TestStoreError.missing(name) }
        return match
    }
}

enum TestStoreError: Error {
    case missing(String)
}
