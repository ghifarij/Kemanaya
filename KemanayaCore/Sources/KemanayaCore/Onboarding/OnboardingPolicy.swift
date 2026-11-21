import Foundation

/// When the first-launch introduction (D-063) opens, and its "seen" flag in `UserDefaults`.
///
/// - **Real store:** it opens until it has been finished once (Mulai, Lewati or Pulihkan dari cadangan),
///   which ``recordSeen()`` remembers. Pengaturan's "Lihat pengenalan lagi" shows it again without
///   touching the flag.
/// - **Throwaway store** (UI tests, unit-test hosts, previews; no `defaults`): it never opens by itself
///   and finishing it is never remembered, so a test can't meet it unexpectedly or change the device's
///   real flag. A test that wants it asks for it (`isRequested`).
public struct OnboardingPolicy {
    /// The `UserDefaults` key of the "seen" flag.
    public static let seenKey = "onboarding.seen"

    private let defaults: UserDefaults?
    private let isRequested: Bool

    /// - Parameters:
    ///   - defaults: where the flag lives; nil for a throwaway store.
    ///   - isRequested: open at launch whatever the flag says (a UI test's launch argument).
    public init(defaults: UserDefaults?, isRequested: Bool = false) {
        self.defaults = defaults
        self.isRequested = isRequested
    }

    /// Whether the introduction has been finished on this install.
    public var hasSeen: Bool {
        defaults?.bool(forKey: Self.seenKey) ?? false
    }

    /// Whether the introduction opens when the app launches.
    public var showsAtLaunch: Bool {
        isRequested || (defaults != nil && !hasSeen)
    }

    /// Remembers that the introduction was finished. Does nothing for a throwaway store.
    public func recordSeen() {
        defaults?.set(true, forKey: Self.seenKey)
    }
}
