import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// Runs retention (D-017, D-059): rolls up and purges every month before the raw window. A no-op unless
/// a transaction is older than the window, and that check is one indexed row, so it runs on launch, on
/// every return to the foreground and when a new month starts while the app is open.
/// Failures are logged, never shown: the next run carries on where this one stopped.
@MainActor
enum RetentionRunner {
    static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Retention")

    static func run(in context: ModelContext, now: Date = .now) {
        do {
            let report = try Retention.run(in: context, now: now, timeZone: .autoupdatingCurrent)
            if report.skippedForPendingChanges {
                logger.info("Retention skipped: unsaved changes are pending; the next run catches up")
            } else if !report.isEmpty {
                let months = report.rolledUpMonths.map(\.description).joined(separator: ", ")
                logger.info("Rolled up \(report.rolledUpMonths.count) month(s) [\(months, privacy: .public)], purged \(report.purgedTransactionCount) transaction(s)")
            }
        } catch {
            logger.error("Retention failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension View {
    /// Runs retention when the scene becomes active and when the current month or time zone changes
    /// (``CurrentMonth``). Launch is covered by `KemanayaApp.init`.
    func runningRetention() -> some View {
        modifier(RetentionTrigger())
    }
}

private struct RetentionTrigger: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var current = CurrentMonth.now

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) {
                if scenePhase == .active { RetentionRunner.run(in: context) }
            }
            // A new month at midnight while the app is open moves the window without a scene change.
            .trackingCurrentMonth($current)
            .onChange(of: current) {
                RetentionRunner.run(in: context)
            }
    }
}
