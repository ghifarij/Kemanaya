import KemanayaCore
import SwiftData
import SwiftUI

/// Where Home's hero leads: one month's transactions (D-068).
struct MonthTransactionsRoute: Hashable {
    let month: MonthKey
    /// The device zone the month was bucketed in, by identifier so the route stays `Hashable`.
    let timeZoneID: String

    init(month: MonthKey, timeZone: TimeZone) {
        self.month = month
        self.timeZoneID = timeZone.identifier
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .autoupdatingCurrent
    }
}

/// This month's transactions, pushed from Home's hero inside Home's navigation stack (D-068): income and
/// expenses, newest first, under Riwayat's sticky day headers (D-053). Tap a row for **Ubah**; swipe for
/// **Hapus** (with the D-043 confirmation) or **Ubah**. Riwayat stays the full 13-month history with search.
struct MonthTransactionsView: View {
    let route: MonthTransactionsRoute

    @Environment(\.locale) private var locale
    @Query private var transactions: [MoneyTransaction]
    @State private var editing: MoneyTransaction?
    @State private var pendingDelete: PendingTransactionDelete?

    init(route: MonthTransactionsRoute) {
        self.route = route
        _transactions = Query(MoneyTransaction.descriptor(in: route.month.dateRange(in: route.timeZone)))
    }

    var body: some View {
        // The fetch is one month, so it groups into at most one month of days, newest first.
        let days = HistoryGrouping.months(transactions, timeZone: route.timeZone).flatMap(\.days)
        Group {
            if days.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(days) { day in
                        Section {
                            ForEach(day.entries) { transaction in
                                row(for: transaction)
                            }
                        } header: {
                            HistoryDayHeader(day: day.day, totals: day.totals, timeZone: route.timeZone)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("home.monthList")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.appBackground).ignoresSafeArea())
        .foregroundStyle(Color(.textPrimary))
        .navigationTitle(Text(verbatim: title))
        .navigationBarTitleDisplayMode(.inline)
        .transactionDeleteAlert($pendingDelete)
        .sheet(item: $editing) { transaction in
            AddTransactionSheet(mode: .edit(transaction))
        }
    }

    private func row(for transaction: MoneyTransaction) -> some View {
        Button {
            editing = transaction
        } label: {
            TransactionRow(transaction: transaction, showsDay: false)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.surface))
        .accessibilityHint(Text("Ketuk untuk mengubah.", comment: "VoiceOver hint on a transaction row in Riwayat and the subcategory detail: tapping opens it for editing (Ubah)."))
        .accessibilityIdentifier("transaction.row")
        .transactionSwipeActions {
            editing = transaction
        } onDelete: {
            pendingDelete = PendingTransactionDelete(transaction)
        }
    }

    /// Nothing logged this month: Si Naya, calm, never a verdict (D-022, D-063).
    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("Belum ada catatan bulan ini", comment: "Empty state title of the month's transactions opened from Home's hero (D-068).")
                    .foregroundStyle(Color(.textPrimary))
            } icon: {
                EmptyStateMascot(mood: .calm, size: 88)
            }
        } description: {
            Text(
                "Catatan bulan ini akan muncul di sini, terbaru di atas.",
                comment: "Empty state description of the month's transactions opened from Home's hero: this month's entries will show here, newest first (D-068)."
            )
            .foregroundStyle(Color(.textSecondary))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.monthList.empty")
    }

    private var title: String {
        route.month.start(in: route.timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: route.timeZone).month(.wide).year())
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        MonthTransactionsView(route: MonthTransactionsRoute(month: CurrentMonth.now.month, timeZone: .autoupdatingCurrent))
    }
    .modelContainer(PreviewStore.makeContainer())
}
#endif
