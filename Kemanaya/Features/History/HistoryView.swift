import KemanayaCore
import SwiftData
import SwiftUI

/// The Riwayat tab (D-053): every transaction of the 13-month raw window (D-017) in one list, newest
/// first, loaded a page of months at a time as you scroll, with native search. "+" in the toolbar opens
/// the add sheet (D-050); a row's tap or swipe opens it for editing, and swipe also deletes (D-043).
/// Search narrows on every keystroke and suggests subcategory names while typing (D-057).
///
/// The filter button beside "+" opens ``HistoryFilterSheet`` (D-074, D-075): three independent groups,
/// each narrowed only by its own subcategory picks, applied with Terapkan, combined with search. While a filter is applied, its icon is filled and a bar of
/// removable chips sits above the list. The filter lasts for the session and is never stored.
struct HistoryView: View {
    /// What the sheet shows.
    enum SheetRoute: Identifiable {
        case add
        case edit(MoneyTransaction)
        case filter

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let transaction): "edit-\(transaction.id)"
            case .filter: "filter"
            }
        }
    }

    @State private var current = CurrentMonth.now
    @State private var pages = HistoryPages(current: CurrentMonth.now.month)
    @State private var query = ""
    @State private var sheet: SheetRoute?
    /// The applied filter (D-074): for this session only, never stored.
    @State private var filter = HistoryFilter()
    /// Every subcategory in grid order, for the search suggestions and the filter.
    @Query(sort: [SortDescriptor(\Subcategory.sortOrder), SortDescriptor(\Subcategory.name)])
    private var subcategories: [Subcategory]

    var body: some View {
        NavigationStack {
            HistoryList(
                pages: pages,
                timeZone: current.timeZone,
                query: query,
                filter: filter,
                filterKinds: filter.allowedKinds,
                onClearFilter: { filter = HistoryFilter() }
            ) {
                pages.loadNextPage(after: $0)
            } onEdit: {
                sheet = .edit($0)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !filter.isEmpty {
                    HistoryFilterBar(
                        filter: filter,
                        subcategories: subcategories.filter { filter.subcategoryIDs.contains($0.id) }.map(Self.option),
                        onRemoveGroup: { filter = filter.removing($0) },
                        onRemoveSubcategory: { filter = filter.removing(subcategory: $0) },
                        onClearAll: { filter = HistoryFilter() }
                    )
                }
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
                    "Kategori, Catatan, atau Jumlah",
                    comment: "Placeholder of the Riwayat search field (D-079): what it matches, the subcategory name, the note, or the amount. Each word capitalised, no 'Search': the field's magnifier already says it."
                )
            )
            .searchSuggestions {
                // Shown subcategory names (D-076), data rather than catalog text. Choosing one fills the field.
                ForEach(suggestions, id: \.self) { name in
                    Text(verbatim: name)
                        .searchCompletion(name)
                        .accessibilityIdentifier("history.suggestion")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterButton
                }
                ToolbarItem(placement: .topBarTrailing) {
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
            case .filter:
                HistoryFilterSheet(applied: filter, options: filterOptions) { filter = $0 }
            }
        }
        .trackingCurrentMonth($current)
        .onChange(of: current) {
            // A new month slides the window; a time zone change alone rebuilds the fetch through `timeZone`.
            pages = pages.moved(to: current.month)
        }
    }

    /// Opens the filter sheet (D-074); filled while a filter is applied. Always there, before "+".
    private var filterButton: some View {
        Button {
            sheet = .filter
        } label: {
            Label {
                Text("Filter", comment: "Riwayat (D-074): the filter sheet's title and the VoiceOver label of the toolbar button that opens it.")
            } icon: {
                Image(systemName: filter.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
        .accessibilityValue(filter.isEmpty ? Text(verbatim: "") : Text(
            "\(filter.count) filter aktif",
            comment: "Riwayat (D-074): VoiceOver value of the filter button while filters are applied, e.g. '2 filter aktif' ('2 filters on'). The placeholder is how many groups and subcategories are selected."
        ))
        .accessibilityIdentifier("history.filter")
    }

    /// The subcategories the filter sheet offers (D-074): those with a transaction in the 13-month window,
    /// hidden ones included, in grid order, so every pick finds something. Built only when the sheet opens.
    private var filterOptions: [HistoryFilterOption] {
        let windowStart = pages.earliest.start(in: current.timeZone)
        return subcategories
            .filter { $0.transactions.contains { $0.date >= windowStart } }
            .map(Self.option)
    }

    private static func option(_ subcategory: Subcategory) -> HistoryFilterOption {
        HistoryFilterOption(id: subcategory.id, name: subcategory.displayName, emoji: subcategory.emoji, section: subcategory.pinSection, storedName: subcategory.name)
    }

    /// Predictive suggestions while typing (D-057): up to 5 shown subcategory names (D-076) containing the
    /// query, none for an empty one. Visible subcategories, plus hidden ones (D-006) only while they have a transaction
    /// in the 13-month window, so a suggestion can always find something. Nothing typed is stored: no
    /// search history, because this is personal finance data.
    private var suggestions: [String] {
        let search = HistorySearch(query)
        guard !search.isEmpty else { return [] }
        let windowStart = pages.earliest.start(in: current.timeZone)
        let names = subcategories.lazy
            .filter { !$0.isHidden || $0.transactions.contains { $0.date >= windowStart } }
            .map(\.displayName)
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
