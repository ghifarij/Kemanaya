import Combine
import KemanayaCore
import SwiftData
import SwiftUI
import UIKit

/// Temporary root screen (D-043): this month's transactions, newest first, with "+" in the toolbar
/// and swipe actions to edit or delete. Home replaces it as the root in Phase 5, and History
/// (Phase 7) starts from it.
struct MonthListView: View {
    /// What the sheet shows.
    enum SheetRoute: Identifiable {
        case add
        case edit(MoneyTransaction)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let transaction): "edit-\(transaction.id)"
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var month = Self.currentMonth
    @State private var sheet: SheetRoute?

    var body: some View {
        NavigationStack {
            MonthTransactionList(month: month) { sheet = .edit($0) }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            sheet = .add
                        } label: {
                            Label {
                                Text(
                                    "Catat transaksi",
                                    comment: "Logging a new transaction: the add sheet's title and the VoiceOver label of the + button that opens it."
                                )
                            } icon: {
                                Image(systemName: "plus")
                            }
                        }
                        .accessibilityIdentifier("month.add")
                    }
                }
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .add: AddTransactionSheet()
            case .edit(let transaction): AddTransactionSheet(mode: .edit(transaction))
            }
        }
        // A new month can start while the app is in the background, at midnight while it is open,
        // or when the clock or time zone changes: re-bucket on each.
        .onChange(of: scenePhase) {
            if scenePhase == .active { month = Self.currentMonth }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
                .receive(on: DispatchQueue.main)
        ) { _ in
            month = Self.currentMonth
        }
    }

    private static var currentMonth: MonthKey {
        MonthKey(containing: .now, timeZone: .autoupdatingCurrent)
    }
}

#if DEBUG
#Preview("With transactions") {
    MonthListView()
        .modelContainer(PreviewStore.makeContainer())
}

#Preview("Empty") {
    MonthListView()
        .modelContainer(PreviewStore.makeContainer(withSamples: false))
}
#endif
