import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// One month's transactions as a list, newest first. `@Query` uses the date-range descriptor
/// (D-018, never the whole table), so adds, edits and deletes show up at once.
struct MonthTransactionList: View {
    /// What the delete dialog shows and deletes: plain values, so the dialog never reads a model
    /// that the delete has already removed.
    struct PendingDelete: Equatable {
        let id: UUID
        let name: String
        let amount: Int64

        init(_ transaction: MoneyTransaction) {
            id = transaction.id
            name = transaction.displayName
            amount = transaction.amount
        }
    }

    let month: MonthKey
    let onEdit: (MoneyTransaction) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Query private var transactions: [MoneyTransaction]
    @State private var pendingDelete: PendingDelete?
    @State private var showsDeleteError = false

    init(month: MonthKey, onEdit: @escaping (MoneyTransaction) -> Void) {
        self.month = month
        self.onEdit = onEdit
        _transactions = Query(MoneyTransaction.descriptor(in: month.dateRange(in: .autoupdatingCurrent)))
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
        .alert(
            Text("Belum terhapus", comment: "Alert title when deleting a transaction failed."),
            isPresented: $showsDeleteError
        ) {
            Button {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: {
            Text("Coba hapus sekali lagi ya.", comment: "Alert message when deleting a transaction failed: asks to try again.")
        }
    }

    private func row(for transaction: MoneyTransaction) -> some View {
        TransactionRow(transaction: transaction)
            .listRowBackground(Color(.surface))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // No `.destructive` role: it would animate the row away before the user confirms.
                Button {
                    pendingDelete = PendingDelete(transaction)
                } label: {
                    Label {
                        Text("Hapus", comment: "Deletes a transaction: the row's swipe action and the confirm button of the delete dialog.")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
                .tint(.red)
                .accessibilityIdentifier("month.row.delete")
                Button {
                    onEdit(transaction)
                } label: {
                    Label {
                        Text("Ubah", comment: "Swipe action on a transaction row that opens it for editing (D-044: editing is 'Ubah' everywhere).")
                    } icon: {
                        Image(systemName: "pencil")
                    }
                }
                .accessibilityIdentifier("month.row.edit")
            }
            // Attached to the row, so it presents for that row only. iOS picks the style: a bottom action
            // sheet with a "Batal" button, or a popover pointing at this row with no Batal (a tap outside
            // cancels). Both have been seen on iOS 26.5 (the screenshot tour got the popover).
            .confirmationDialog(
                Text("Hapus transaksi ini?", comment: "Title of the dialog confirming that a transaction is deleted."),
                isPresented: isConfirmingDelete(of: transaction.id),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { target in
                Button(role: .destructive) {
                    pendingDelete = nil
                    delete(target)
                } label: {
                    Text("Hapus", comment: "Deletes a transaction: the row's swipe action and the confirm button of the delete dialog.")
                }
                .accessibilityIdentifier("month.delete.confirm")
                Button(role: .cancel) {} label: {
                    Text("Batal", comment: "Cancels: closes the add sheet without saving, or the delete dialog without deleting.")
                }
            } message: { target in
                Text(
                    "\(target.name) sebesar \(target.amount.rupiahFormatted) akan dihapus permanen.",
                    comment: "Message of the delete dialog. 1: subcategory name, e.g. Makan. 2: the amount, e.g. Rp30.000."
                )
            }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: AppInfo.name)
                .font(.brandTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("root.title")
            Text(month.start(in: .autoupdatingCurrent), format: Date.FormatStyle.gregorian(locale: locale).month(.wide).year())
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

    /// Presented on the row whose transaction is pending deletion.
    private func isConfirmingDelete(of id: UUID) -> Binding<Bool> {
        Binding(
            get: { pendingDelete?.id == id },
            set: { if !$0, pendingDelete?.id == id { pendingDelete = nil } }
        )
    }

    /// Deletes by id, so a transaction already gone (deleted elsewhere) is simply skipped.
    private func delete(_ target: PendingDelete) {
        do {
            try Ledger(context: context, timeZone: .autoupdatingCurrent).deleteTransaction(id: target.id)
        } catch {
            Logger(subsystem: "com.afgaghifari.kemanaya", category: "MonthList")
                .error("Deleting a transaction failed: \(error.localizedDescription, privacy: .public)")
            showsDeleteError = true
        }
    }
}
