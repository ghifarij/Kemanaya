import KemanayaCore
import SwiftData
import SwiftUI

/// The Riwayat tab (D-053): every transaction of the 13-month raw window (D-017) in one list, newest
/// first, loaded a page of months at a time as you scroll, with native search. "+" in the toolbar opens
/// the add sheet (D-050); a row's tap or swipe opens it for editing, and swipe also deletes (D-043).
/// Search narrows on every keystroke and suggests subcategory names while typing (D-057).
struct HistoryView: View {
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
    @State private var pages = HistoryPages(current: CurrentMonth.now.month)
    @State private var query = ""
    @State private var sheet: SheetRoute?
    /// Every subcategory, for the search suggestions.
    @Query private var subcategories: [Subcategory]

    var body: some View {
        NavigationStack {
            HistoryList(pages: pages, timeZone: current.timeZone, query: query) {
                pages.loadNextPage(after: $0)
            } onEdit: {
                sheet = .edit($0)
            }
            .navigationTitle(Text(
                "Riwayat",
                comment: "Title of the Riwayat (history) tab and its tab bar item: every transaction of the last 13 months, searchable."
            ))
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(
                    "Cari kategori, catatan, atau jumlah",
                    comment: "Placeholder of the Riwayat search field: it matches the subcategory name, the note, or the amount."
                )
            )
            .searchSuggestions {
                // Subcategory names are user data, shown as typed (D-023). Choosing one fills the field.
                ForEach(suggestions, id: \.self) { name in
                    Text(verbatim: name)
                        .searchCompletion(name)
                        .accessibilityIdentifier("history.suggestion")
                }
            }
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
                    .accessibilityIdentifier("history.add")
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
        .onChange(of: current) {
            // A new month slides the window; a time zone change alone rebuilds the fetch through `timeZone`.
            pages = pages.moved(to: current.month)
        }
    }

    /// Predictive suggestions while typing (D-057): up to 5 subcategory names containing the query, none
    /// for an empty one. Visible subcategories, plus hidden ones (D-006) only while they have a transaction
    /// in the 13-month window, so a suggestion can always find something. Nothing typed is stored: no
    /// search history, because this is personal finance data.
    private var suggestions: [String] {
        let search = HistorySearch(query)
        guard !search.isEmpty else { return [] }
        let windowStart = pages.earliest.start(in: current.timeZone)
        let names = subcategories.lazy
            .filter { !$0.isHidden || $0.transactions.contains { $0.date >= windowStart } }
            .map(\.name)
        return search.suggestions(from: names)
    }
}

#if DEBUG
#Preview("Months of history") {
    let container = PreviewStore.makeContainer(withSamples: false)
    try? DebugSample.transactions.apply(to: container.mainContext)
    return HistoryView()
        .modelContainer(container)
}

#Preview("Empty") {
    HistoryView()
        .modelContainer(PreviewStore.makeContainer(withSamples: false))
}
#endif
