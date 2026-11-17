import SwiftData

/// The newest schema. Point it at the new version on every migration; everything else follows.
public typealias CurrentSchema = KemanayaSchemaV1

/// The first persisted schema. Models are nested here so a later `KemanayaSchemaV2`
/// can redefine them and ``KemanayaMigrationPlan`` can migrate between the two.
///
/// **Frozen once a device has real data.** Any later model change goes into a new V2
/// plus a migration stage, never into V1.
public enum KemanayaSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Subcategory.self, MoneyTransaction.self, MonthlyRollup.self, AppSettings.self]
    }
}

// The current schema's models under their plain names.
public typealias Subcategory = CurrentSchema.Subcategory
public typealias MoneyTransaction = CurrentSchema.MoneyTransaction
public typealias MonthlyRollup = CurrentSchema.MonthlyRollup
public typealias AppSettings = CurrentSchema.AppSettings
