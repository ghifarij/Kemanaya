import KemanayaCore
import SwiftData
import SwiftUI

/// History's list (D-053): the loaded months, each with a header and its days under sticky day headers,
/// newest first. `@Query` fetches the loaded months' date range (D-018), so adds, edits and deletes show
/// up at once. It asks for the next page of older months when the end of the list comes into view, and
/// on its own while the loaded months hold fewer than ``fillCount`` rows to show, until the window's
/// oldest month is loaded. So a sparse history, an empty one, or a search with few matches still covers
/// the whole window without any scrolling.
///
/// Search filters the loaded transactions and keeps the day grouping (D-057); Riwayat's filter (D-074,
/// D-075) narrows them too, and both must match. Month headers then total only the rows shown, with a figure
/// only for the kinds the filter lets through. The fetch has no upper date bound, so an entry dated in a
/// later month shows at the top.
struct HistoryList: View {
    /// About a screenful of rows. Fewer than this and the list loads the next page by itself.
    static let fillCount = 20

    /// What the automatic paging re-checks on: a new page, a new search or filter, or rows coming or going.
    private struct PagingKey: Equatable {
        let oldestLoaded: MonthKey
        let query: String
        let filter: HistoryFilter
        let needsMore: Bool
    }

    let pages: HistoryPages
    let timeZone: TimeZone
    /// The search field's text, as typed.
    let query: String
    /// The applied filter (D-074, D-075); empty shows everything.
    let filter: HistoryFilter
    /// The kinds `filter` lets through, for the month headers' figures.
    let filterKinds: Set<TransactionKind>
    /// Clears the filter: the no-results notes' "Hapus filter".
    let onClearFilter: () -> Void
    /// Asks for the page after the given oldest loaded month (``HistoryPages/loadNextPage(after:)``).
    let onLoadMore: (MonthKey) -> Void
    let onEdit: (MoneyTransaction) -> Void

    @Query private var transactions: [MoneyTransaction]
    @State private var pendingDelete: PendingTransactionDelete?

    /// New pages, a new month or time zone from the parent re-run `init`, which rebuilds the range.
    init(
        pages: HistoryPages,
        timeZone: TimeZone,
        query: String,
        filter: HistoryFilter = HistoryFilter(),
        filterKinds: Set<TransactionKind> = Set(TransactionKind.allCases),
        onClearFilter: @escaping () -> Void = {},
        onLoadMore: @escaping (MonthKey) -> Void,
        onEdit: @escaping (MoneyTransaction) -> Void
    ) {
        self.pages = pages
        self.timeZone = timeZone
        self.query = query
        self.filter = filter
        self.filterKinds = filterKinds
        self.onClearFilter = onClearFilter
        self.onLoadMore = onLoadMore
        self.onEdit = onEdit
        _transactions = Query(MoneyTransaction.historyDescriptor(pages, timeZone: timeZone))
    }

    var body: some View {
        let search = HistorySearch(query)
        let filter = filter
        // One pass over the fetch: no search and no filter groups it as is, without folding a thing;
        // otherwise rows are filtered lazily while grouping. No cache: edits change the models in place,
        // which a cache key over the fetched array wouldn't see.
        let months = search.isEmpty && filter.isEmpty
            ? HistoryGrouping.months(transactions, timeZone: timeZone)
            : HistoryGrouping.months(
                transactions.lazy.filter {
                    filter.matches($0) && search.matches(names: $0.searchNames, note: $0.note, amount: $0.amount)
                },
                timeZone: timeZone
            )
        let needsMore = pages.hasMore && Self.rowCount(months, upTo: Self.fillCount) < Self.fillCount
        Group {
            if months.isEmpty, !pages.hasMore {
                if !search.isEmpty {
                    noResults
                } else if !filter.isEmpty {
                    noFilterResults
                } else {
                    emptyState
                }
            } else {
                list(months)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.appBackground).ignoresSafeArea())
        .foregroundStyle(Color(.textPrimary))
        .transactionDeleteAlert($pendingDelete)
        // The action reads the key it is handed, never values captured with it: on iOS 18 a re-run
        // `.task(id:)` kept the first page's values, so paging stopped after one page and an empty or
        // sparse history spun forever.
        .onChange(of: PagingKey(oldestLoaded: pages.oldestLoaded, query: query, filter: filter, needsMore: needsMore), initial: true) { _, key in
            if key.needsMore { onLoadMore(key.oldestLoaded) }
        }
    }

    /// The rows `months` show, counting no further than `limit`.
    private static func rowCount(_ months: [HistoryMonth<MoneyTransaction>], upTo limit: Int) -> Int {
        var count = 0
        for month in months {
            for day in month.days {
                count += day.entries.count
                if count >= limit { return count }
            }
        }
        return count
    }

    private func list(_ months: [HistoryMonth<MoneyTransaction>]) -> some View {
        List {
            ForEach(months) { month in
                Section {
                    HistoryMonthHeader(month: month.month, totals: month.totals, timeZone: timeZone, kinds: filterKinds)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                ForEach(month.days) { day in
                    Section {
                        ForEach(day.entries) { transaction in
                            row(for: transaction)
                        }
                    } header: {
                        HistoryDayHeader(day: day.day, timeZone: timeZone)
                    }
                }
            }
            if pages.hasMore {
                Section {
                    loadingRow
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("history.list")
    }

    private func row(for transaction: MoneyTransaction) -> some View {
        Button {
            onEdit(transaction)
        } label: {
            TransactionRow(transaction: transaction, showsDay: false)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.surface))
        .accessibilityHint(Text("Ketuk untuk mengubah.", comment: "VoiceOver hint on a transaction row in Riwayat and the subcategory detail: tapping opens it for editing (Ubah)."))
        .accessibilityIdentifier("transaction.row")
        .transactionSwipeActions {
            onEdit(transaction)
        } onDelete: {
            pendingDelete = PendingTransactionDelete(transaction)
        }
    }

    /// The end of the loaded months. Coming into view loads the next page, and so does each new page
    /// while it stays in view.
    private var loadingRow: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityLabel(Text("Memuat catatan sebelumnya", comment: "VoiceOver label of the spinner at the end of Riwayat while older months load."))
            .accessibilityIdentifier("history.loading")
            .onAppear {
                onLoadMore(pages.oldestLoaded)
            }
            .onChange(of: pages.oldestLoaded) { _, oldest in
                onLoadMore(oldest)
            }
    }

    /// Nothing logged in the whole window: Si Naya, calm, friendly and neutral (D-022, D-063).
    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("Belum ada catatan", comment: "Empty state title of Riwayat: nothing logged in the last 13 months.")
                    .foregroundStyle(Color(.textPrimary))
            } icon: {
                EmptyStateMascot(mood: .calm, size: 88)
            }
        } description: {
            Text(
                "Ketuk + untuk mencatat pengeluaran atau pemasukan pertamamu.",
                comment: "Empty state description of Riwayat: tap + to log the first expense or income."
            )
            .foregroundStyle(Color(.textSecondary))
        }
        // One element, read as one, like Home's and Analisis' empty notes; Si Naya is decorative.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.empty")
    }

    /// The filter found nothing in the whole window (D-074): Si Naya, calm, and a way out.
    private var noFilterResults: some View {
        ContentUnavailableView {
            Label {
                Text("Belum ada transaksi untuk filter ini", comment: "Riwayat filter (D-074): title when no transaction in the last 13 months matches the applied filter.")
                    .foregroundStyle(Color(.textPrimary))
            } icon: {
                EmptyStateMascot(mood: .calm, size: 88)
            }
        } description: {
            Text(
                "Tidak ada catatan yang cocok dalam 13 bulan terakhir.",
                comment: "Riwayat filter (D-074): description when nothing in the 13-month window matches the applied filter."
            )
            .foregroundStyle(Color(.textSecondary))
        } actions: {
            clearFilterButton
        }
        // A container, not one combined element: "Hapus filter" stays its own button.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.noFilterResults")
    }

    /// "Hapus filter": clears every filter (D-074).
    private var clearFilterButton: some View {
        Button(action: onClearFilter) {
            Text("Hapus filter", comment: "Riwayat (D-074): the button under a no-results note that clears every filter.")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.brand))
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("history.noResults.clearFilter")
    }

    /// The search found nothing in the whole window: Si Naya, curious, still looking (D-063). With a
    /// filter on, "Hapus filter" too (D-074).
    private var noResults: some View {
        ContentUnavailableView {
            Label {
                Text("Tidak ada yang cocok", comment: "Riwayat search: title when no transaction matches the search.")
                    .foregroundStyle(Color(.textPrimary))
            } icon: {
                EmptyStateMascot(mood: .curious, size: 88)
            }
        } description: {
            Text(
                "Tidak ada catatan untuk “\(query.trimmingCharacters(in: .whitespacesAndNewlines))” dalam 13 bulan terakhir. Coba nama kategori, isi catatan, atau jumlahnya, misalnya 18000.",
                comment: "Riwayat search: description when nothing matches. 1: the search text as typed. Suggests searching by subcategory name, note text or amount."
            )
            .foregroundStyle(Color(.textSecondary))
        } actions: {
            if !filter.isEmpty {
                clearFilterButton
            }
        }
        // A container, not one combined element: "Hapus filter" stays its own button.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.noResults")
    }
}

#if DEBUG
private extension HistoryPages {
    /// Every month of the window loaded, so a preview needs no paging.
    static var wholeWindow: HistoryPages {
        let current = CurrentMonth.now.month
        return HistoryPages(current: current, oldestLoaded: current.adding(months: -RetentionWindow.monthsBeforeCurrent))
    }
}

#Preview("Search by amount") {
    let container = PreviewStore.makeContainer(withSamples: false)
    try? DebugSample.transactions.apply(to: container.mainContext)
    return NavigationStack {
        HistoryList(pages: .wholeWindow, timeZone: .autoupdatingCurrent, query: "18.000") { _ in } onEdit: { _ in }
    }
    .modelContainer(container)
}

#Preview("Filtered: Keinginan") {
    let container = PreviewStore.makeContainer(withSamples: false)
    try? DebugSample.transactions.apply(to: container.mainContext)
    let filter = HistoryFilter(groups: [.keinginan])
    return NavigationStack {
        HistoryList(pages: .wholeWindow, timeZone: .autoupdatingCurrent, query: "", filter: filter, filterKinds: [.expense]) { _ in } onEdit: { _ in }
            .safeAreaInset(edge: .top, spacing: 0) {
                HistoryFilterBar(filter: filter, subcategories: [], onRemoveGroup: { _ in }, onRemoveSubcategory: { _ in }, onClearAll: {})
            }
            .navigationTitle(Text(verbatim: "Riwayat"))
    }
    .modelContainer(container)
}

#Preview("Filtered: no matches") {
    NavigationStack {
        HistoryList(pages: .wholeWindow, timeZone: .autoupdatingCurrent, query: "", filter: HistoryFilter(groups: [.pemasukan]), filterKinds: [.income]) { _ in } onEdit: { _ in }
    }
    .modelContainer(PreviewStore.makeContainer(withSamples: false))
}

#Preview("No results") {
    NavigationStack {
        HistoryList(pages: .wholeWindow, timeZone: .autoupdatingCurrent, query: "sepeda") { _ in } onEdit: { _ in }
    }
    .modelContainer(PreviewStore.makeContainer())
}
#endif
