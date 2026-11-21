import KemanayaCore
import SwiftData
import SwiftUI

/// The root: a native tab bar (D-021, D-048, D-051) with **Beranda** (Home), **Riwayat** (every transaction
/// of the 13-month window, searchable, D-053), **Analisis** (breakdown and trends) and **Pengaturan** (budgets,
/// subcategories, backup and export, D-060, D-062).
/// Launching with `-gallerySection <name>` shows the design gallery instead, for screenshots.
/// Home and the gallery keep the `root.title` identifier on their title for the UI tests.
/// The tabs also run retention on foreground and month changes (D-059, ``RetentionRunner``), and write a
/// pending automatic backup when the app goes to the background (``AutoBackup``).
///
/// "Pulihkan dari cadangan" (D-060) has one ``RestoreController`` for Home and Pengaturan, with its
/// confirmation alert here. After a restore each tab's content gets a new identity
/// (``RestoreController/generation``): open screens, pushed details and sheets that held a deleted model
/// are rebuilt from the restored data. The selected tab stays.
///
/// The introduction (D-063) is a full-screen cover over the tabs, from ``Onboarding``: on first launch,
/// and again from Pengaturan's "Lihat pengenalan lagi". Its "Pulihkan dari cadangan" closes it, then
/// switches to Beranda and asks Home to open the backup picker, so the restore runs as it does from
/// Home's own link. The design gallery never shows it.
struct RootView: View {
    enum Destination: Hashable {
        case home, history, analysis, settings
    }

    @State private var selection = Destination.home
    @State private var restore = RestoreController()
    @Environment(AutoBackup.self) private var autoBackup
    @Environment(Onboarding.self) private var onboarding
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if DesignGalleryView.GallerySection.isRequested {
            DesignGalleryView()
        } else {
            TabView(selection: $selection) {
                Tab(
                    String(localized: "Beranda", comment: "Tab bar: the Home tab, with the month's totals and pinned cards."),
                    systemImage: "house",
                    value: Destination.home
                ) {
                    HomeView()
                        .id(restore.generation)
                }
                Tab(
                    String(
                        localized: "Riwayat",
                        comment: "Title of the Riwayat (history) tab and its tab bar item: every transaction of the last 13 months, searchable."
                    ),
                    systemImage: "list.bullet",
                    value: Destination.history
                ) {
                    HistoryView()
                        .id(restore.generation)
                }
                Tab(
                    String(localized: "Analisis", comment: "Title of the Analisis tab and its tab bar item: spending breakdown and trends."),
                    systemImage: "chart.pie",
                    value: Destination.analysis
                ) {
                    AnalysisView()
                        .id(restore.generation)
                }
                Tab(
                    String(localized: "Pengaturan", comment: "Title of the Pengaturan (settings) tab and its tab bar item."),
                    systemImage: "gearshape",
                    value: Destination.settings
                ) {
                    SettingsView(onShowIntroduction: { onboarding.show() })
                        .id(restore.generation)
                }
            }
            .environment(restore)
            .restoreConfirmation(restore)
            .fullScreenCover(isPresented: Bindable(onboarding).isPresented, onDismiss: afterIntroduction) {
                OnboardingView(onFinish: onboarding.finish, onRestore: onboarding.finishAndRestore)
            }
            .runningRetention()
            .onChange(of: scenePhase) {
                // The 5 s timer may not get to run once the app is suspended.
                if scenePhase == .background { autoBackup.flush() }
            }
        }
    }

    /// Onboarding's "Pulihkan dari cadangan": the picker opens on Home once the cover is gone (D-060, D-063).
    private func afterIntroduction() {
        guard onboarding.takeRestoreRequest() else { return }
        selection = .home
        restore.requestPicker(on: .home)
    }
}

#if DEBUG
#Preview {
    let container = PreviewStore.makeContainer()
    RootView()
        .modelContainer(container)
        .environment(AutoBackup(container: container, defaults: nil))
        .environment(Onboarding(policy: OnboardingPolicy(defaults: nil)))
}

#Preview("Introduction") {
    let container = PreviewStore.makeContainer(withSamples: false)
    RootView()
        .modelContainer(container)
        .environment(AutoBackup(container: container, defaults: nil))
        .environment(Onboarding(policy: OnboardingPolicy(defaults: nil, isRequested: true)))
}
#endif
