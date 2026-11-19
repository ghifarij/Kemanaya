import Combine
import KemanayaCore
import SwiftUI
import UIKit

/// The month on screen and the device time zone it was bucketed in (D-017). A screen keeps one in `@State`
/// and builds its month queries from both, so a time zone change within the same month (whose
/// ``MonthKey`` doesn't change) still rebuilds the date ranges.
struct CurrentMonth: Equatable {
    var month: MonthKey
    /// The device zone's identifier, e.g. `Asia/Jakarta`.
    var timeZoneID: String

    /// The month that contains now, in the device time zone.
    static var now: CurrentMonth {
        let zone = TimeZone.autoupdatingCurrent
        return CurrentMonth(month: MonthKey(containing: .now, timeZone: zone), timeZoneID: zone.identifier)
    }

    /// The zone that `month`'s date range is built in.
    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .autoupdatingCurrent
    }
}

extension View {
    /// Keeps `current` on the current month and time zone. A new month can start while the app is in the
    /// background, at midnight while it is open, or when the clock or time zone changes: it re-buckets on each.
    func trackingCurrentMonth(_ current: Binding<CurrentMonth>) -> some View {
        modifier(CurrentMonthTracking(current: current))
    }
}

private struct CurrentMonthTracking: ViewModifier {
    @Binding var current: CurrentMonth
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) {
                if scenePhase == .active { refresh() }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
                    .receive(on: DispatchQueue.main)
            ) { _ in
                refresh()
            }
    }

    /// Assigns only on a change, so an unchanged month doesn't re-render the screen.
    private func refresh() {
        let now = CurrentMonth.now
        if now != current { current = now }
    }
}
