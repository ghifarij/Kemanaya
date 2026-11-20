import Foundation
import KemanayaCore

/// Whether the introduction (D-063) is on screen. `KemanayaApp` makes the one instance, with the launch's
/// ``OnboardingPolicy``; `RootView` presents ``OnboardingView`` as a full-screen cover from it, and
/// Pengaturan's "Lihat pengenalan lagi" calls ``show()``.
///
/// **Pulihkan dari cadangan** on the last page finishes the introduction and leaves a request:
/// once the cover is gone, `RootView` takes it (``takeRestoreRequest()``) and asks Home to open the
/// backup picker, so the D-060 restore flow (picker, confirmation alert, inline status) runs where it
/// always does, never on top of the cover.
@Observable
final class Onboarding {
    #if DEBUG
    /// Launch argument for UI tests and screenshots: open the introduction even on a throwaway store.
    /// Debug builds only; without it a throwaway store never shows it (``OnboardingPolicy``).
    static let showArgument = "-showOnboarding"
    #endif

    var isPresented: Bool
    /// Set by ``finishAndRestore()`` until `RootView` takes it.
    private(set) var restoreRequested = false

    @ObservationIgnored private let policy: OnboardingPolicy

    init(policy: OnboardingPolicy) {
        self.policy = policy
        isPresented = policy.showsAtLaunch
    }

    /// "Lihat pengenalan lagi": shows the introduction again from its first page.
    func show() {
        isPresented = true
    }

    /// Mulai or Lewati: remembered, so it doesn't open on the next launch.
    func finish() {
        policy.recordSeen()
        isPresented = false
    }

    /// Pulihkan dari cadangan: finishes, and asks for the backup picker once the cover is gone.
    func finishAndRestore() {
        restoreRequested = true
        finish()
    }

    /// Whether a restore was asked for; clears the request.
    func takeRestoreRequest() -> Bool {
        defer { restoreRequested = false }
        return restoreRequested
    }
}
