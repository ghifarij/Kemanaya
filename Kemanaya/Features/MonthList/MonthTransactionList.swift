import KemanayaCore
import SwiftData
import SwiftUI

/// One month's transactions as a list, newest first. `@Query` uses the date-range descriptor
/// (D-018, never the whole table), so adds, edits and deletes show up at once. A new month or time
/// zone from the parent re-runs `init`, which rebuilds the range.
struct MonthTransactionList: View {
    let month: MonthKey
    let timeZone: TimeZone
    let onEdit: (MoneyTransaction) -> Void

    @Environment(\.locale) private var locale
    @Query private var transactions: [MoneyTransaction]
    @State private var pendingDelete: PendingTransactionDelete?

    init(month: MonthKey, timeZone: TimeZone, onEdit: @escaping (MoneyTransaction) -> Void) {
        self.month = month
        self.timeZone = timeZone
        self.onEdit = onEdit
        _transactions = Query(MoneyTransaction.descriptor(in: month.dateRange(in: timeZone)))
    }

    var body: some View {
        List {
            header
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            if transactions.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(transactions) { transaction in
                        row(for: transaction)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground).ignoresSafeArea())
        .foregroundStyle(Color(.textPrimary))
        .transactionDeleteAlert($pendingDelete)
    }

    private func row(for transaction: MoneyTransaction) -> some View {
        TransactionRow(transaction: transaction)
            .listRowBackground(Color(.surface))
            .transactionSwipeActions {
                onEdit(transaction)
            } onDelete: {
                pendingDelete = PendingTransactionDelete(transaction)
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: AppInfo.name)
                .font(.brandTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("month.header")
            Text(month.start(in: timeZone), format: Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .accessibilityIdentifier("month.title")
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
    }

    /// Friendly and neutral: an empty month is neither good nor bad (D-022).
    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("Belum ada catatan bulan ini", comment: "Empty state title of the month list.")
                    .foregroundStyle(Color(.textPrimary))
            } icon: {
                Image(systemName: "tray")
                    .foregroundStyle(Color(.textSecondary))
            }
        } description: {
            Text(
                "Ketuk + untuk mencatat pengeluaran atau pemasukan pertamamu.",
                comment: "Empty state description of the month list: tap + to log the first expense or income."
            )
            .foregroundStyle(Color(.textSecondary))
        }
        .accessibilityIdentifier("month.empty")
    }
}
