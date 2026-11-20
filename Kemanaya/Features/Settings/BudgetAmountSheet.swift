import KemanayaCore
import OSLog
import SwiftUI

/// Types a standing monthly budget on the app's rupiah keypad (D-041, D-062): Kebutuhan and Keinginan
/// from Pengaturan, and a subcategory's budget from its editor.
///
/// **Simpan** hands back the typed amount; zero is not a budget, so saving 0 clears it (nil). **Hapus
/// anggaran** shows only when a budget is set and hands back nil. The keypad stops at
/// ``AmountEntry/maximum``, the most a budget can be. The caller saves, so a refused or failed save can
/// keep the sheet open: `onSave` throws, and the sheet then shows a short note instead of closing.
///
/// No praise and no alarm here (D-022): it is only a number.
struct BudgetAmountSheet: View {
    private let title: Text
    private let note: Text
    private let current: Int64?
    private let onSave: (Int64?) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var entry: AmountEntry
    @State private var rejectedKeyCount = 0
    @State private var showsSaveError = false

    /// - Parameters:
    ///   - title: e.g. "Anggaran Kebutuhan".
    ///   - note: one line under the amount explaining what the budget covers.
    ///   - current: the budget now, or nil when none is set.
    ///   - onSave: receives the new budget, nil to clear it. Throws when it couldn't be saved.
    init(title: Text, note: Text, current: Int64?, onSave: @escaping (Int64?) throws -> Void) {
        self.title = title
        self.note = note
        self.current = current
        self.onSave = onSave
        _entry = State(initialValue: AmountEntry(amount: current ?? 0))
    }

    var body: some View {
        NavigationStack {
            Group {
                if dynamicTypeSize >= .xxLarge {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                            keypad
                            removeButton
                        }
                        .padding(16)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        removeButton
                        Spacer(minLength: 0)
                        keypad
                    }
                    .padding(16)
                }
            }
            .foregroundStyle(Color(.textPrimary))
            .background(Color(.appBackground).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .sensoryFeedback(.warning, trigger: rejectedKeyCount)
        .alert(
            Text("Anggaran belum tersimpan", comment: "Alert title when saving a budget failed and trying again may work."),
            isPresented: $showsSaveError
        ) {
            Button {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: {
            Text("Coba simpan sekali lagi ya.", comment: "Alert message when a save failed (a transaction, a budget or a subcategory): asks to try again.")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AmountText(entry.amount, size: .hero)
                    .foregroundStyle(entry.isEmpty ? Color(.textSecondary) : Color(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("budget.amount")
                if !entry.isEmpty {
                    Button {
                        entry.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(.textSecondary))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(Text("Kosongkan jumlah", comment: "VoiceOver label for the button that clears the typed amount back to 0."))
                    .accessibilityIdentifier("budget.clear")
                }
            }
            Text(Self.perMonth)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            note
                .font(.footnote)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keypad: some View {
        RupiahKeypad(identifierPrefix: "budget.key") { press($0) }
    }

    @ViewBuilder private var removeButton: some View {
        if current != nil {
            Button(role: .destructive) {
                save(nil)
            } label: {
                Label {
                    Text("Hapus anggaran", comment: "Budget sheet: removes the budget, so none is set any more.")
                } icon: {
                    Image(systemName: "trash")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.brand))
                .frame(minHeight: 44)
            }
            .accessibilityIdentifier("budget.remove")
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Text("Batal", comment: "Cancels: closes a sheet or dialog without saving, deleting or restoring (the add sheet, the delete dialogs, the restore alert, the budget sheet and the subcategory editor).")
            }
            .accessibilityIdentifier("budget.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                // Zero is not a budget (D-062): saving 0 clears it.
                save(entry.isEmpty ? nil : entry.amount)
            } label: {
                Text("Simpan", comment: "Saves: the transaction in the add / edit sheet, the amount in the budget sheet, or the subcategory in its editor.")
            }
            .accessibilityIdentifier("budget.save")
        }
    }

    // MARK: - Actions

    private func press(_ key: KeypadInput) {
        switch entry.press(key) {
        case .accepted:
            if voiceOverEnabled {
                AccessibilityNotification.Announcement(
                    String(localized: "\(entry.amount) rupiah", comment: "VoiceOver reading of a money amount. The number is whole rupiah, without separators.")
                ).post()
            }
        case .rejectedAtCap:
            rejectedKeyCount += 1
        case .ignored:
            break
        }
    }

    private func save(_ amount: Int64?) {
        do {
            try onSave(amount)
            dismiss()
        } catch {
            SettingsLog.logger.error("Saving a budget failed: \(error.localizedDescription, privacy: .public)")
            showsSaveError = true
        }
    }

    private static let perMonth = LocalizedStringResource(
        "per bulan, berlaku setiap bulan sampai kamu ubah",
        comment: "Budget sheet: under the amount. A budget is one standing monthly amount that applies every month until changed (D-041)."
    )
}

/// The Pengaturan feature's log.
enum SettingsLog {
    static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Settings")
}

#if DEBUG
#Preview("Set") {
    BudgetAmountSheet(
        title: Text(verbatim: "Anggaran Kebutuhan"),
        note: Text(verbatim: "Semua pengeluaran Kebutuhan dalam sebulan."),
        current: 3_000_000
    ) { _ in }
}

#Preview("Not set") {
    BudgetAmountSheet(title: Text(verbatim: "Anggaran Kopi"), note: Text(verbatim: ""), current: nil) { _ in }
}
#endif
