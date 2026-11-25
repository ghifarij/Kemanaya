import KemanayaCore
import SwiftUI

extension AppearanceSetting {
    /// The segment's name in Pengaturan's Tampilan picker (D-078), the iOS wording in English.
    var title: LocalizedStringResource {
        switch self {
        case .automatic:
            LocalizedStringResource("Otomatis", comment: "Pengaturan, Tampilan: follow the iPhone's light or dark appearance (D-078). Use the iOS wording.")
        case .light:
            LocalizedStringResource("Terang", comment: "Pengaturan, Tampilan: always the light appearance (D-078). Use the iOS wording.")
        case .dark:
            LocalizedStringResource("Gelap", comment: "Pengaturan, Tampilan: always the dark appearance (D-078). Use the iOS wording.")
        }
    }

    /// What `preferredColorScheme` gets: nil follows the iPhone.
    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The app's root wrapper for D-078: applies Pengaturan's Tampilan choice with `preferredColorScheme`, which
/// sets the whole window's appearance, so tabs, sheets and full-screen covers (onboarding, the store error
/// screen) all follow at once. The choice is read from the environment's `defaultAppStorage`.
struct AppearanceRoot<Content: View>: View {
    @AppStorage(AppearanceSetting.storageKey) private var appearance = AppearanceSetting.default
    @ViewBuilder let content: Content

    var body: some View {
        content.preferredColorScheme(appearance.colorScheme)
    }
}

enum AppearanceDefaults {
    /// Where the Tampilan choice lives: the real defaults, or for a throwaway store (UI tests, unit-test
    /// hosts) a suite emptied at every launch, so a choice made on the device never changes a test's or a
    /// screenshot's appearance, and a test never changes the device's choice.
    static func store(real defaults: UserDefaults?) -> UserDefaults {
        if let defaults { return defaults }
        let name = "com.afgaghifari.kemanaya.throwaway"
        guard let throwaway = UserDefaults(suiteName: name) else { return .standard }
        throwaway.removePersistentDomain(forName: name)
        return throwaway
    }
}
