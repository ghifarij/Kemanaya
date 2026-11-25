import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

@main
struct KemanayaApp: App {
    #if DEBUG
    /// Launch argument for UI tests and screenshots: use a throwaway in-memory store, never the real data.
    /// Debug builds only, so a release build always opens the real store.
    static let inMemoryStoreArgument = "-inMemoryStore"
    #endif

    /// What the app opens on.
    private enum Launch {
        /// The store is open: the tabs, with the automatic backup (D-019, D-060) and the introduction (D-063).
        case ready(ModelContainer, AutoBackup, Onboarding)
        /// The store won't open: ``StoreErrorView`` instead of a crash (D-063). The store is left as it is.
        case storeUnavailable(StoreRescue)
    }

    private let launch: Launch
    /// Where Pengaturan's Tampilan choice lives (D-078): `UserDefaults`, device-only, never in a backup.
    private let appearanceDefaults: UserDefaults

    init() {
        #if DEBUG
        let process = ProcessInfo.processInfo
        // Unit tests are hosted by the app, so they get a throwaway store too.
        let inMemory = process.arguments.contains(Self.inMemoryStoreArgument)
            || process.environment["XCTestConfigurationFilePath"] != nil
        #else
        let inMemory = false
        #endif
        // Throwaway stores remember nothing: no backup folder, no writes, no onboarding flag.
        let defaults: UserDefaults? = inMemory ? nil : .standard
        appearanceDefaults = AppearanceDefaults.store(real: defaults)
        let container: ModelContainer
        do {
            #if DEBUG
            if let simulated = SimulatedStoreFailure.fromLaunchArguments {
                launch = .storeUnavailable(simulated.rescue)
                return
            }
            #endif
            container = try KemanayaStore.makeContainer(inMemory: inMemory)
        } catch {
            // Never delete or migrate the store here: the error screen offers what can be saved, and the
            // next launch tries the store again as it is.
            StoreRescue.logger.fault("Could not open the data store: \(String(describing: error), privacy: .public)")
            launch = .storeUnavailable(.current(after: error, defaults: defaults))
            return
        }
        do {
            try Seeder.seedIfNeeded(in: container.mainContext)
        } catch {
            // The app still runs without the seed; the next launch tries again.
            Logger(subsystem: "com.afgaghifari.kemanaya", category: "Seed")
                .error("Seeding failed: \(error.localizedDescription, privacy: .public)")
        }
        #if DEBUG
        // Sample budgets / transactions for UI tests and screenshots, only ever into a throwaway store.
        if process.arguments.contains(Self.inMemoryStoreArgument), let sample = DebugSample.fromLaunchArguments {
            do {
                try sample.apply(to: container.mainContext)
            } catch {
                fatalError("Debug sample failed: \(error)")
            }
        }
        let showsOnboarding = process.arguments.contains(Onboarding.showArgument)
        #else
        let showsOnboarding = false
        #endif
        // After seeding (and any debug sample), so an app left closed for months catches up before the
        // first screen reads its totals (D-059).
        RetentionRunner.run(in: container.mainContext)
        // After retention, so the launch backup holds what the first screen shows.
        let autoBackup = AutoBackup(container: container, defaults: defaults)
        autoBackup.start()
        // A throwaway store (UI tests, the DEBUG samples) skips the introduction unless asked for.
        let onboarding = Onboarding(policy: OnboardingPolicy(defaults: defaults, isRequested: showsOnboarding))
        launch = .ready(container, autoBackup, onboarding)
    }

    var body: some Scene {
        WindowGroup {
            // The Tampilan choice wraps everything, the store error screen included (D-078).
            AppearanceRoot {
                switch launch {
                case .ready(let container, let autoBackup, let onboarding):
                    RootView()
                        .environment(autoBackup)
                        .environment(onboarding)
                        .modelContainer(container)
                case .storeUnavailable(let rescue):
                    StoreErrorView(rescue: rescue)
                }
            }
            .defaultAppStorage(appearanceDefaults)
        }
    }
}
