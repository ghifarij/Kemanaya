import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// What the delete alert shows and deletes: plain values, so the alert never reads a model that the
/// delete has already removed.
struct PendingTransactionDelete: Equatable {
    let id: UUID
    let name: String
    let amount: Int64

    init(_ transaction: MoneyTransaction) {
        id = transaction.id
        name = transaction.displayName
        amount = transaction.amount
    }
}

extension View {
    /// A transaction row's swipe actions, **Hapus** then **Ubah** (D-043, D-044), shared by Riwayat (D-053) and
    /// the subcategory detail (D-051). Hapus only asks: pair it with ``transactionDeleteAlert(_:)``.
    func transactionSwipeActions(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // No `.destructive` role: it would animate the row away before the user confirms.
            Button(action: onDelete) {
                Label {
                    Text("Hapus", comment: "Deletes a transaction: the row's swipe action and the confirm button of the delete dialog.")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .tint(.red)
            .accessibilityIdentifier("transaction.row.delete")
            Button(action: onEdit) {
                Label {
                    Text("Ubah", comment: "Opens something for editing: a transaction row's swipe action, and the Home card menu item that edits the card's subcategory (D-044: editing is 'Ubah' everywhere).")
                } icon: {
                    Image(systemName: "pencil")
                }
            }
            .accessibilityIdentifier("transaction.row.edit")
        }
    }

    /// The delete confirmation (D-043): an alert naming the amount and subcategory, with **Hapus** and
    /// **Batal**, shown while `pending` is set. Confirming deletes by id; a failure shows a short alert.
    /// Attach it once to the list, not to each row.
    func transactionDeleteAlert(_ pending: Binding<PendingTransactionDelete?>) -> some View {
        modifier(TransactionDeleteAlert(pending: pending))
    }
}

private struct TransactionDeleteAlert: ViewModifier {
    @Binding var pending: PendingTransactionDelete?

    @Environment(\.modelContext) private var context
    @State private var showsDeleteError = false

    func body(content: Content) -> some View {
        content
            // An alert, not a confirmationDialog: on iOS 26 a confirmationDialog presents as a narrow popover
            // (pointing at the row, or at the top of the list when attached there), which breaks words at
            // large text sizes and drops "Batal". An alert is centred and full-width on iOS 18 and 26 alike.
            .alert(
                Text("Hapus transaksi ini?", comment: "Title of the dialog confirming that a transaction is deleted."),
                isPresented: isConfirming,
                presenting: pending
            ) { target in
                Button(role: .destructive) {
                    pending = nil
                    delete(target)
                } label: {
                    Text("Hapus", comment: "Deletes a transaction: the row's swipe action and the confirm button of the delete dialog.")
                }
                .accessibilityIdentifier("transaction.delete.confirm")
                Button(role: .cancel) {} label: {
                    Text("Batal", comment: "Cancels: closes a sheet or dialog without saving, deleting or restoring (the add sheet, the delete dialogs, the restore alert, the budget sheet and the subcategory editor).")
                }
            } message: { target in
                Text(
                    "\(target.name) sebesar \(target.amount.rupiahFormatted) akan dihapus permanen.",
                    comment: "Message of the delete dialog. 1: subcategory name, e.g. Makan. 2: the amount, e.g. Rp30.000."
                )
            }
            .alert(
                Text("Belum terhapus", comment: "Alert title when deleting a transaction failed."),
                isPresented: $showsDeleteError
            ) {
                Button {} label: { Text("OK", comment: "Dismisses an alert.") }
            } message: {
                Text("Coba hapus sekali lagi ya.", comment: "Alert message when deleting a transaction failed: asks to try again.")
            }
    }

    /// Presented while a transaction is pending deletion; dismissing it clears the pending one.
    private var isConfirming: Binding<Bool> {
        Binding(
            get: { pending != nil },
            set: { if !$0 { pending = nil } }
        )
    }

    /// Deletes by id, so a transaction already gone (deleted elsewhere) is simply skipped.
    private func delete(_ target: PendingTransactionDelete) {
        do {
            try Ledger(context: context, timeZone: .autoupdatingCurrent).deleteTransaction(id: target.id)
        } catch {
            Logger(subsystem: "com.afgaghifari.kemanaya", category: "Transactions")
                .error("Deleting a transaction failed: \(error.localizedDescription, privacy: .public)")
            showsDeleteError = true
        }
    }
}
