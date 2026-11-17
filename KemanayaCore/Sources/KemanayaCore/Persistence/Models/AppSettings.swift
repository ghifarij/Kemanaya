import Foundation
import SwiftData

extension KemanayaSchemaV1 {
    /// The single settings row. Get it with ``fetchOrCreate(in:)``, never by inserting one.
    @Model
    public final class AppSettings {
        /// Standing monthly budget for Kebutuhan, applied every month; nil = no budget (D-010).
        public private(set) var kebutuhanBudget: Int64?
        /// Standing monthly budget for Keinginan, applied every month; nil = no budget (D-010).
        public private(set) var keinginanBudget: Int64?
        /// The newest ``SeedData/version`` already applied. 0 = never seeded.
        public var seedVersion: Int

        init(seedVersion: Int = 0) {
            self.seedVersion = seedVersion
        }

        /// The budget for `group`, or nil when none is set.
        public func budget(for group: ExpenseGroup) -> Int64? {
            switch group {
            case .kebutuhan: kebutuhanBudget
            case .keinginan: keinginanBudget
            }
        }

        /// Sets or clears the budget for `group`. Zero or negative clears it.
        public func setBudget(_ amount: Int64?, for group: ExpenseGroup) {
            let value = amount.flatMap { $0 > 0 ? $0 : nil }
            switch group {
            case .kebutuhan: kebutuhanBudget = value
            case .keinginan: keinginanBudget = value
            }
        }

        /// The settings row, inserting it on first use. Does not save.
        ///
        /// Only this method inserts settings, so there is one row. If a bug ever left duplicates,
        /// the row with the highest `seedVersion` wins every time (deterministic), and the rest are ignored.
        public static func fetchOrCreate(in context: ModelContext) throws -> AppSettings {
            var descriptor = FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.seedVersion, order: .reverse)])
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                return existing
            }
            let settings = AppSettings()
            context.insert(settings)
            return settings
        }
    }
}
