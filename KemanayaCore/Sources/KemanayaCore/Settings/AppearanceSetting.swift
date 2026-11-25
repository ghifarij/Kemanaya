/// The app's appearance (D-078): follow the iPhone (Otomatis, the default), always light (Terang) or
/// always dark (Gelap). Device-only: stored in `UserDefaults` under ``storageKey``, never in a backup.
public enum AppearanceSetting: String, CaseIterable, Sendable {
    case automatic
    case light
    case dark

    /// The `UserDefaults` key. Stored raw values are stable: renaming a case would reset everyone's choice.
    public static let storageKey = "appearance"

    /// Otomatis.
    public static let `default` = AppearanceSetting.automatic

    /// The setting stored as `rawValue`; the default for nothing stored or an unknown value.
    public init(storedValue rawValue: String?) {
        self = rawValue.flatMap(Self.init(rawValue:)) ?? .default
    }
}
