import SwiftData

/// Every schema version, oldest first, and the stages between them. Empty until V2 exists.
public enum KemanayaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [KemanayaSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
