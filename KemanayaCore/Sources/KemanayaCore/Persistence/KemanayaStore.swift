import Foundation
import SwiftData

/// Creates the app's `ModelContainer` (D-015: local only, no CloudKit).
public enum KemanayaStore {
    /// The current schema (``CurrentSchema``).
    public static var schema: Schema { Schema(versionedSchema: CurrentSchema.self) }

    /// - Parameter inMemory: true for tests, previews and UI tests, so real data is never touched.
    ///   Each in-memory container gets its own name, so parallel containers never share a store.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try makeContainer(
                ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        }
        // The default store lives in Application Support, which a fresh install doesn't have yet.
        // Creating it first avoids Core Data's "Failed to stat path" error-and-recover on first launch.
        try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        return try makeContainer(ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none))
    }

    /// An on-disk store at `url`, through the same schema and migration plan. For tests.
    static func makeContainer(storeURL url: URL) throws -> ModelContainer {
        try makeContainer(ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
    }

    private static func makeContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: schema, migrationPlan: KemanayaMigrationPlan.self, configurations: configuration)
    }
}
