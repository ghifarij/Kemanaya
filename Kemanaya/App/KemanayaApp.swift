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

    private let container: ModelContainer

    init() {
        #if DEBUG
        let process = ProcessInfo.processInfo
        // Unit tests are hosted by the app, so they get a throwaway store too.
        let inMemory = process.arguments.contains(Self.inMemoryStoreArgument)
            || process.environment["XCTestConfigurationFilePath"] != nil
        #else
        let inMemory = false
        #endif
        do {
            container = try KemanayaStore.makeContainer(inMemory: inMemory)
        } catch {
            // Without a store the app can't do anything useful; fail loudly instead of losing data silently.
            fatalError("Could not open the data store: \(error)")
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
        #endif
        // After seeding (and any debug sample), so an app left closed for months catches up before the
        // first screen reads its totals (D-059).
        RetentionRunner.run(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
