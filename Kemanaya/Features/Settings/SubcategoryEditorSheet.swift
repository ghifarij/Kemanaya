import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// Adds or edits (**Ubah**) a subcategory (D-062), from Kelola subkategori and from a Home card's menu.
///
/// Fields: one emoji (``SubcategoryRules/isValidEmoji(_:)``); a one-word name of at most ten characters
/// with a live counter and the reason when it can't be saved (D-007), unique across both kinds ignoring
/// case and diacritics; the Kebutuhan / Keinginan group, chosen only when adding an expense and fixed
/// afterwards (D-004; income has none, D-005); and an optional monthly budget for expenses on the
/// rupiah keypad (D-041). **Simpan** is disabled until valid. Every rule lives in ``SubcategoryDraft``
/// and every write in ``Ledger``; this view draws and forwards.
///
/// Editing also offers **Hapus subkategori**: deleted when nothing refers to it, hidden when it has
/// history (D-006, which unpins it, D-049), and never for the last visible one of its kind or group.
/// The confirmation says which before anything happens.
struct SubcategoryEditorSheet: View {
    enum Mode: Identifiable {
        /// A new subcategory of this kind, added at the end of its section.
        case add(TransactionKind)
        /// **Ubah** on this subcategory.
        case edit(Subcategory)

        var id: String {
            switch self {
            case .add(let kind): "add-\(kind.rawValue)"
            case .edit(let subcategory): "edit-\(subcategory.id)"
            }
        }
    }

    /// Why a save didn't happen, for the alert.
    private enum SaveProblem {
        /// A rule refused it, e.g. another device-level change made the name taken meanwhile.
        case rejected
        /// SwiftData failed to save; trying again may work.
        case saveFailed
    }

    private enum Field: Hashable {
        case emoji, name
    }

    private let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Every subcategory of both kinds, hidden ones included: their names are taken (D-062).
    @Query private var all: [Subcategory]
    @State private var draft: SubcategoryDraft
    /// What Hapus subkategori would do; nil while adding.
    @State private var removal: SubcategoryRemoval?
    @State private var showsBudgetSheet = false
    @State private var showsRemoveConfirmation = false
    @State private var problem: SaveProblem?
    @State private var savedCount = 0
    @FocusState private var focus: Field?

    init(mode: Mode) {
        self.mode = mode
        let draft = switch mode {
        case .add(let kind): SubcategoryDraft(kind: kind, group: kind == .expense ? .kebutuhan : nil)
        case .edit(let subcategory): SubcategoryDraft(subcategory)
        }
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                emojiSection
                nameSection
                if draft.kind == .expense {
                    groupSection
                    budgetSection
                }
                removeSection
            }
            .scrollContentBackground(.hidden)
            .background(Color(.appBackground).ignoresSafeArea())
            .accessibilityIdentifier("editor.form")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .onAppear(perform: loadRemoval)
        .sheet(isPresented: $showsBudgetSheet) {
            BudgetAmountSheet(
                title: Text(
                    "Anggaran \(draft.trimmedName)",
                    comment: "Title of the budget sheet for one subcategory, e.g. 'Anggaran Kopi'. The placeholder is the subcategory name (user data)."
                ),
                note: Text(
                    "Hanya untuk kategori ini. Tidak harus pas dengan anggaran kelompoknya.",
                    comment: "Budget sheet for one subcategory: the note under the amount. A subcategory budget need not add up to its group's budget (D-041)."
                ),
                current: draft.monthlyBudget
            ) { amount in
                draft.monthlyBudget = amount
            }
        }
        .alert(
            removeTitle,
            isPresented: $showsRemoveConfirmation
        ) {
            Button(role: .destructive) {
                remove()
            } label: {
                if removal == .hide {
                    Text("Sembunyikan", comment: "Confirm button of the dialog that hides a subcategory with history instead of deleting it (D-006).")
                } else {
                    Text("Hapus subkategori", comment: "Subcategory editor: the button that deletes the subcategory (or hides it when it has history), and the confirm button of the delete dialog.")
                }
            }
            .accessibilityIdentifier("editor.remove.confirm")
            Button(role: .cancel) {} label: {
                Text("Batal", comment: "Cancels: closes a sheet or dialog without saving, deleting or restoring (the add sheet, the delete dialogs, the restore alert, the budget sheet and the subcategory editor).")
            }
        } message: {
            removeMessage
        }
        .alert(
            Text("Subkategori belum tersimpan", comment: "Alert title when saving, deleting or hiding a subcategory failed."),
            isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } }),
            presenting: problem
        ) { _ in
            Button {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: { problem in
            switch problem {
            case .rejected:
                Text(
                    "Periksa lagi emoji dan namanya ya.",
                    comment: "Alert message when a subcategory can't be saved as entered (e.g. the name became taken meanwhile)."
                )
            case .saveFailed:
                Text("Coba simpan sekali lagi ya.", comment: "Alert message when a save failed (a transaction, a budget or a subcategory): asks to try again.")
            }
        }
    }

    // MARK: - Sections

    private var emojiSection: some View {
        Section {
            HStack(spacing: 12) {
                TextField(
                    text: Binding(get: { draft.emoji }, set: { draft.setEmojiInput($0) }),
                    prompt: Text("Pilih emoji", comment: "Subcategory editor: placeholder of the emoji field.")
                ) {
                    Text("Emoji", comment: "Subcategory editor: label of the emoji field and header of its section.")
                }
                .font(.largeTitle)
                .focused($focus, equals: .emoji)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                .onSubmit { focus = .name }
                .frame(minHeight: 44)
                .accessibilityIdentifier("editor.emoji")
                if draft.hasValidEmoji {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(.brand))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Color(.textPrimary))
            .listRowBackground(Color(.surface))
        } header: {
            Text("Emoji", comment: "Subcategory editor: label of the emoji field and header of its section.")
        } footer: {
            Group {
                if draft.emoji.isEmpty || draft.hasValidEmoji {
                    Text(
                        "Satu emoji. Ganti papan ketik ke emoji, lalu pilih satu.",
                        comment: "Subcategory editor: footer of the emoji field explaining it takes one emoji from the emoji keyboard."
                    )
                } else {
                    Label {
                        Text("Pakai satu emoji saja, bukan huruf atau angka.", comment: "Subcategory editor: the emoji field holds text that isn't one emoji.")
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .accessibilityIdentifier("editor.emojiProblem")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameSection: some View {
        let problem = nameProblem
        // At accessibility sizes the counter goes under the field, so a ten-letter name stays in view.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return Section {
            layout {
                TextField(
                    text: $draft.name,
                    prompt: Text("Misalnya Bakso", comment: "Subcategory editor: placeholder of the name field, an example name.")
                ) {
                    Text("Nama", comment: "Subcategory editor: label of the name field and header of its section.")
                }
                .focused($focus, equals: .name)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .frame(minHeight: 44)
                .accessibilityIdentifier("editor.name")
                Text(verbatim: "\(draft.nameLength)/\(SubcategoryRules.maximumNameLength)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color(.textSecondary))
                    .fixedSize()
                    .accessibilityLabel(Text(
                        "\(draft.nameLength) dari \(SubcategoryRules.maximumNameLength) huruf",
                        comment: "VoiceOver reading of the name counter in the subcategory editor, e.g. '5 dari 10 huruf'."
                    ))
                    .accessibilityIdentifier("editor.counter")
            }
            .foregroundStyle(Color(.textPrimary))
            .listRowBackground(Color(.surface))
        } header: {
            Text("Nama", comment: "Subcategory editor: label of the name field and header of its section.")
        } footer: {
            Group {
                if let problem, problem != .empty {
                    Label {
                        nameProblemText(problem)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .accessibilityIdentifier("editor.nameProblem")
                } else {
                    Text(
                        "Satu kata, paling banyak \(SubcategoryRules.maximumNameLength) huruf. Pakai nama keperluannya, bukan merek: Ojol, bukan Grab.",
                        comment: "Subcategory editor: footer of the name field with the naming rule (D-007). The placeholder is the maximum length (10)."
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var groupSection: some View {
        Section {
            if case .add = mode {
                Picker(selection: Binding(get: { draft.group ?? .kebutuhan }, set: { draft.group = $0 })) {
                    ForEach(ExpenseGroup.allCases, id: \.self) { group in
                        Text(group.title).tag(group)
                    }
                } label: {
                    Text("Kelompok", comment: "Subcategory editor: the Kebutuhan / Keinginan group, the header of its section and the label of its picker.")
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("editor.group")
            } else if let group = draft.group {
                Text(group.title)
                    .foregroundStyle(Color(.textPrimary))
                    .listRowBackground(Color(.surface))
                    .accessibilityIdentifier("editor.group")
            }
        } header: {
            Text("Kelompok", comment: "Subcategory editor: the Kebutuhan / Keinginan group, the header of its section and the label of its picker.")
        } footer: {
            Text(
                "Kelompok tidak bisa diubah setelah subkategori dibuat.",
                comment: "Subcategory editor: footer of the group section. The group is chosen when adding and is fixed afterwards (D-004)."
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var budgetSection: some View {
        Section {
            Button {
                focus = nil
                showsBudgetSheet = true
            } label: {
                BudgetRowLabel(
                    title: Text("Anggaran bulanan", comment: "Subcategory editor: the row that opens the subcategory's optional monthly budget."),
                    amount: draft.monthlyBudget
                )
            }
            .listRowBackground(Color(.surface))
            .accessibilityIdentifier("editor.budget")
        } footer: {
            Text(
                "Opsional. Tampil sebagai progres di kartunya.",
                comment: "Subcategory editor: footer of the budget row. The budget is optional and shows as progress on the subcategory's card (D-041)."
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Editing only. Hidden for an already hidden subcategory with history: there is nothing left to do.
    @ViewBuilder private var removeSection: some View {
        if case .edit(let subcategory) = mode, let removal, !(subcategory.isHidden && removal == .hide) {
            Section {
                Button(role: .destructive) {
                    focus = nil
                    showsRemoveConfirmation = true
                } label: {
                    Text("Hapus subkategori", comment: "Subcategory editor: the button that deletes the subcategory (or hides it when it has history), and the confirm button of the delete dialog.")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .disabled(removal == .notAllowed)
                .listRowBackground(Color(.surface))
                .accessibilityIdentifier("editor.remove")
            } footer: {
                Group {
                    if removal == .notAllowed {
                        Text(
                            "Ini satu-satunya subkategori yang tampil di kelompoknya, jadi tidak bisa dihapus.",
                            comment: "Subcategory editor: under the disabled delete button. The last visible subcategory of its kind or group can't be removed, so the add sheet always has a tile (D-062)."
                        )
                    } else if removal == .hide {
                        Text(
                            "Sudah ada catatan di sini, jadi subkategori ini disembunyikan, bukan dihapus.",
                            comment: "Subcategory editor: under the delete button when the subcategory has history, so it will be hidden instead (D-006)."
                        )
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("editor.removeNote")
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Text("Batal", comment: "Cancels: closes a sheet or dialog without saving, deleting or restoring (the add sheet, the delete dialogs, the restore alert, the budget sheet and the subcategory editor).")
            }
            .accessibilityIdentifier("editor.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(action: save) {
                Text("Simpan", comment: "Saves: the transaction in the add / edit sheet, the amount in the budget sheet, or the subcategory in its editor.")
            }
            .disabled(!draft.canSave(takenNames: takenNames))
            .accessibilityIdentifier("editor.save")
        }
    }

    // MARK: - Derived

    private var title: Text {
        switch mode {
        case .add(.expense):
            Text("Pengeluaran baru", comment: "Title of the subcategory editor when adding an expense subcategory.")
        case .add(.income):
            Text("Pemasukan baru", comment: "Title of the subcategory editor when adding an income subcategory.")
        case .edit:
            Text("Ubah subkategori", comment: "Title of the subcategory editor when editing an existing subcategory.")
        }
    }

    private var edited: Subcategory? {
        if case .edit(let subcategory) = mode { subcategory } else { nil }
    }

    /// Every other subcategory's name: the edited one may keep its own, or change only its case.
    private var takenNames: [String] {
        let editedID = edited?.id
        return all.filter { $0.id != editedID }.map(\.name)
    }

    private var nameProblem: SubcategoryNameProblem? {
        draft.nameProblem(takenNames: takenNames)
    }

    private func nameProblemText(_ problem: SubcategoryNameProblem) -> Text {
        switch problem {
        case .empty:
            Text("Isi namanya dulu.", comment: "Subcategory editor: the name is empty.")
        case .notOneWord:
            Text("Pakai satu kata saja, tanpa spasi.", comment: "Subcategory editor: the name has more than one word (D-007).")
        case .tooLong:
            Text(
                "Paling banyak \(SubcategoryRules.maximumNameLength) huruf, supaya muat di kartu.",
                comment: "Subcategory editor: the name is too long. The placeholder is the maximum (10). Names must fit on the cards (D-007)."
            )
        case .taken:
            Text(
                "Nama ini sudah dipakai subkategori lain, termasuk yang tersembunyi.",
                comment: "Subcategory editor: another subcategory, of either kind and hidden or not, already has this name (ignoring case and accents, D-062)."
            )
        }
    }

    private var removeTitle: Text {
        let name = edited?.name ?? ""
        return if removal == .hide {
            Text("Sembunyikan \(name)?", comment: "Title of the dialog that hides a subcategory with history instead of deleting it. The placeholder is its name.")
        } else {
            Text("Hapus \(name)?", comment: "Title of the dialog that deletes a subcategory without history. The placeholder is its name.")
        }
    }

    private var removeMessage: Text {
        if removal == .hide {
            if edited?.isPinned == true {
                Text(
                    "Sudah ada catatan di subkategori ini, jadi tidak dihapus tapi disembunyikan. Riwayatnya tetap ada, kartunya dilepas dari Beranda, dan kamu bisa menampilkannya lagi dari Tersembunyi.",
                    comment: "Message of the dialog that hides a pinned subcategory with history (D-006, D-049): its history stays, its card leaves Home, and it can be shown again from the Tersembunyi section."
                )
            } else {
                Text(
                    "Sudah ada catatan di subkategori ini, jadi tidak dihapus tapi disembunyikan. Riwayatnya tetap ada, dan kamu bisa menampilkannya lagi dari Tersembunyi.",
                    comment: "Message of the dialog that hides a subcategory with history (D-006): its history stays and it can be shown again from the Tersembunyi section."
                )
            }
        } else {
            Text(
                "Belum ada catatan di subkategori ini, jadi akan dihapus permanen.",
                comment: "Message of the dialog that deletes a subcategory without history: it is deleted for good."
            )
        }
    }

    private var ledger: Ledger {
        Ledger(context: context, timeZone: .autoupdatingCurrent)
    }

    // MARK: - Actions

    private func loadRemoval() {
        guard let edited else { return }
        do {
            removal = try ledger.removal(for: edited)
        } catch {
            Self.logger.error("Checking a subcategory's history failed: \(error.localizedDescription, privacy: .public)")
            removal = nil
        }
    }

    private func save() {
        do {
            if let edited {
                try ledger.updateSubcategory(edited, name: draft.name, emoji: draft.emoji, monthlyBudget: draft.monthlyBudget)
            } else {
                try ledger.addSubcategory(
                    name: draft.name,
                    emoji: draft.emoji,
                    kind: draft.kind,
                    group: draft.group,
                    monthlyBudget: draft.monthlyBudget
                )
            }
            savedCount += 1
            dismiss()
        } catch is SubcategoryError {
            problem = .rejected
        } catch is BudgetError {
            problem = .rejected
        } catch {
            Self.logger.error("Saving a subcategory failed: \(error.localizedDescription, privacy: .public)")
            problem = .saveFailed
        }
    }

    private func remove() {
        guard let edited else { return }
        do {
            _ = try withAnimation {
                try ledger.removeSubcategory(edited)
            }
            dismiss()
        } catch {
            Self.logger.error("Removing a subcategory failed: \(error.localizedDescription, privacy: .public)")
            loadRemoval()
            problem = .saveFailed
        }
    }

    private static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Subcategories")
}

/// A budget row: the title, and the amount or "Belum diatur" (D-062). Side by side at regular sizes,
/// stacked at accessibility sizes so the amount keeps its full width.
struct BudgetRowLabel: View {
    let title: Text
    let amount: Int64?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        layout {
            title
                .foregroundStyle(Color(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            Group {
                if let amount {
                    AmountText(amount, size: .small)
                        .foregroundStyle(Color(.textPrimary))
                } else {
                    Text("Belum diatur", comment: "A budget row with no budget set: Pengaturan's Kebutuhan and Keinginan rows and the subcategory editor's budget row.")
                        .foregroundStyle(Color(.textSecondary))
                }
            }
            .accessibilityIdentifier("budget.value")
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}

#if DEBUG
#Preview("Add") {
    SubcategoryEditorSheet(mode: .add(.expense))
        .modelContainer(PreviewStore.makeContainer())
}
#endif
