import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// Types a standing monthly budget on the app's rupiah keypad (D-041, D-062): a group's or a subcategory's,
/// from the Anggaran sheet or a card's menu (D-077; see ``BudgetTargetSheet``).
///
/// **Simpan** hands back the typed amount; zero is not a budget, so saving 0 clears it (nil). **Hapus
/// anggaran** shows only when a budget is set and hands back nil. The keypad stops at
/// ``AmountEntry/maximum``, the most a budget can be. The caller saves, so a refused or failed save can
/// keep the sheet open: `onSave` throws, and the sheet then shows a short note instead of closing.
///
/// Under the amount, one caption, "per bulan" (D-080). No praise and no alarm here (D-022): it is only a
/// number.
struct BudgetAmountSheet: View {
    private let title: Text
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
    ///   - current: the budget now, or nil when none is set.
    ///   - onSave: receives the new budget, nil to clear it. Throws when it couldn't be saved.
    init(title: Text, current: Int64?, onSave: @escaping (Int64?) throws -> Void) {
        self.title = title
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
        "per bulan",
        comment: "Budget sheet: the one caption under the amount. A budget is one standing monthly amount (D-041, D-080)."
    )
}

/// Whose standing monthly budget a ``BudgetAmountSheet`` edits (D-041): one expense group's or one
/// expense subcategory's. Both entry points, the Anggaran sheet and a card's menu (D-077), open
/// ``BudgetTargetSheet`` with one of these, so they show the same sheet and save through the same
/// ``Ledger`` call; SwiftData observation keeps the value the same everywhere.
enum BudgetTarget: Identifiable {
    case group(ExpenseGroup)
    /// An expense subcategory; income has no budget (D-005).
    case subcategory(Subcategory)

    var id: String {
        switch self {
        case .group(let group): "group-\(group.rawValue)"
        case .subcategory(let subcategory): "subcategory-\(subcategory.id)"
        }
    }
}

/// ``BudgetAmountSheet`` for a ``BudgetTarget``: shows the budget now and saves the new one through
/// ``Ledger/setGroupBudget(_:for:)`` or ``Ledger/setMonthlyBudget(_:for:)`` (D-062, D-077).
struct BudgetTargetSheet: View {
    let target: BudgetTarget

    @Environment(\.modelContext) private var context
    /// The settings row, as ``AppSettings/fetchOrCreate(in:)`` picks it; none until the first write.
    @Query(sort: \AppSettings.seedVersion, order: .reverse) private var settings: [AppSettings]

    var body: some View {
        switch target {
        case .group(let group):
            let name = String(localized: group.title)
            BudgetAmountSheet(
                title: BudgetCopy.sheetTitle(name),
                current: settings.first?.budget(for: group)
            ) { amount in
                try ledger.setGroupBudget(amount, for: group)
            }
        case .subcategory(let subcategory):
            BudgetAmountSheet(
                title: BudgetCopy.sheetTitle(subcategory.displayName),
                current: subcategory.monthlyBudget
            ) { amount in
                try ledger.setMonthlyBudget(amount, for: subcategory)
            }
        }
    }

    private var ledger: Ledger {
        Ledger(context: context, timeZone: .autoupdatingCurrent)
    }
}

/// Budget wording shared by every screen that shows or sets a budget, so each phrase is one catalog key
/// with one translator comment (D-023).
enum BudgetCopy {
    /// "Atur anggaran": a Home card's menu item, which opens that subcategory's budget keypad (D-069, D-077).
    static let setBudget = LocalizedStringResource(
        "Atur anggaran",
        comment: "Home card menu item and VoiceOver action that opens the subcategory's monthly budget keypad (D-069, D-077)."
    )

    /// "Anggaran": the hero's link and the title of the sheet listing every budget (D-077).
    static let budgets = LocalizedStringResource(
        "budgets.title",
        defaultValue: "Anggaran",
        comment: "The Anggaran sheet listing every group and subcategory budget: its title, and the small link on Home's hero that opens it (D-077). Plural sense in English (Budgets)."
    )

    /// "Belum diatur": a budget that isn't set, as VoiceOver reads it.
    static let notSet = LocalizedStringResource(
        "Belum diatur",
        comment: "VoiceOver reading of a row on the Anggaran sheet without a budget, a group or a subcategory (D-077, D-080)."
    )

    /// "Selesai": closes a sheet whose changes are already saved (Atur kartu, Anggaran).
    static let done = LocalizedStringResource(
        "Selesai",
        comment: "Closes a sheet whose changes are already saved: Atur kartu (pin management) and the Anggaran sheet (D-077)."
    )

    /// "Anggaran Kopi": a budget sheet's title.
    static func sheetTitle(_ name: String) -> Text {
        Text(
            "Anggaran \(name)",
            comment: "Title of a budget keypad sheet, and a group row on the Anggaran sheet: a group's, e.g. 'Anggaran Kebutuhan', or one subcategory's, e.g. 'Anggaran Kopi' (D-077). The placeholder is the group or subcategory name."
        )
    }
}

/// The Pengaturan feature's log.
enum SettingsLog {
    static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Settings")
}

#if DEBUG
#Preview("Set") {
    BudgetAmountSheet(title: Text(verbatim: "Anggaran Kebutuhan"), current: 3_000_000) { _ in }
}

#Preview("Not set") {
    BudgetAmountSheet(title: Text(verbatim: "Anggaran Kopi"), current: nil) { _ in }
}
#endif
