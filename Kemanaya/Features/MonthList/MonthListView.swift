import KemanayaCore
import SwiftData
import SwiftUI

/// The Riwayat tab (D-048): this month's transactions, newest first, with "+" in the toolbar and swipe
/// actions to edit or delete (D-043). History (Phase 7) starts from it.
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

    @State private var current = CurrentMonth.now
    @State private var sheet: SheetRoute?

    var body: some View {
        NavigationStack {
            MonthTransactionList(month: current.month, timeZone: current.timeZone) { sheet = .edit($0) }
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
        .trackingCurrentMonth($current)
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
