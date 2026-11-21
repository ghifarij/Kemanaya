import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// Kelola subkategori (D-062), pushed from Pengaturan: a **Pengeluaran | Pemasukan** switch, then the
/// visible subcategories of that kind (Kebutuhan and Keinginan sections for expenses, one list for income)
/// in the add sheet's grid order, then **Tersembunyi** with a **Tampilkan** button on each hidden one.
///
/// - A row shows the emoji, the name, the budget when set and a pin glyph when pinned on Home; tapping
///   it opens the editor (**Ubah**). "+" adds one to the kind on screen.
/// - **Edit** mode drags a row within its own section; that order is the add sheet's grid order. VoiceOver
///   gets "Geser ke atas / ke bawah" actions instead.
/// - Tampilkan shows a subcategory again without pinning it (D-049).
///
/// Every change saves at once through ``Ledger``.
struct SubcategoryListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Both kinds, hidden ones included, in grid order (as ``Ledger/subcategories(of:)``).
    @Query(sort: [SortDescriptor(\Subcategory.sortOrder), SortDescriptor(\Subcategory.name)])
    private var all: [Subcategory]
    @State private var kind = TransactionKind.expense
    @State private var editMode = EditMode.inactive
    @State private var editor: SubcategoryEditorSheet.Mode?
    @State private var showsSaveError = false

    var body: some View {
        List {
            kindPicker
            ForEach(sections) { section in
                visibleSection(section)
            }
            if !hidden.isEmpty {
                hiddenSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground).ignoresSafeArea())
        .accessibilityIdentifier("subcategories.list")
        .navigationTitle(Text("Kelola subkategori", comment: "Pengaturan: the row that opens subcategory management, and that screen's title."))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = .add(kind)
                } label: {
                    Label {
                        Text("Tambah subkategori", comment: "VoiceOver label of the + button in Kelola subkategori: adds a subcategory of the kind on screen.")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .disabled(editMode.isEditing)
                .accessibilityIdentifier("subcategories.add")
            }
            ToolbarItem(placement: .primaryAction) {
                EditButton()
                    .accessibilityIdentifier("subcategories.edit")
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(item: $editor) { mode in
            SubcategoryEditorSheet(mode: mode)
        }
        .alert(
            Text("Perubahan belum tersimpan", comment: "Alert title in Kelola subkategori when saving a reorder or Tampilkan failed."),
            isPresented: $showsSaveError
        ) {
            Button {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: {
            Text("Coba ubah sekali lagi ya.", comment: "Alert message when saving a change failed (a pin, the order of cards or subcategories, or Tampilkan): asks to try again.")
        }
    }

    // MARK: - Data

    /// Visible subcategories of the kind on screen, split as the add sheet's grid splits them.
    private var sections: [SubcategorySection] {
        SubcategorySection.sections(from: live.filter { $0.kind == kind && !$0.isHidden }, kinds: [kind])
    }

    private var hidden: [Subcategory] {
        live.filter { $0.kind == kind && $0.isHidden }
    }

    /// The query's results minus one the editor just deleted, should a redraw come before the query
    /// catches up: a deleted model's properties can't be read.
    private var live: [Subcategory] {
        all.filter { $0.modelContext != nil && !$0.isDeleted }
    }

    // MARK: - Sections

    private var kindPicker: some View {
        Picker(selection: $kind) {
            ForEach(TransactionKind.allCases, id: \.self) { kind in
                Text(kind.title).tag(kind)
            }
        } label: {
            Text("Jenis subkategori", comment: "Accessibility label of the expense/income switch in Kelola subkategori.")
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .accessibilityIdentifier("subcategories.kind")
    }

    private func visibleSection(_ section: SubcategorySection) -> some View {
        let subcategories = section.subcategories
        return Section {
            ForEach(Array(subcategories.enumerated()), id: \.element.id) { index, subcategory in
                Button {
                    guard !editMode.isEditing else { return }
                    editor = .editing(subcategory)
                } label: {
                    row(for: subcategory)
                }
                .listRowBackground(Color(.surface))
                .accessibilityHint(Text("Ketuk untuk mengubah.", comment: "VoiceOver hint on a Kelola subkategori row: tapping it opens the subcategory editor."))
                .accessibilityIdentifier("subcategories.row.\(subcategory.name)")
                .accessibilityActions {
                    if index > 0 {
                        Button {
                            move(section, from: index, to: index - 1)
                        } label: {
                            Text("Geser ke atas", comment: "VoiceOver action on a reorderable row (a pinned card in Atur kartu, or a subcategory in Kelola subkategori): moves it one place earlier.")
                        }
                    }
                    if index < subcategories.count - 1 {
                        Button {
                            move(section, from: index, to: index + 2)
                        } label: {
                            Text("Geser ke bawah", comment: "VoiceOver action on a reorderable row (a pinned card in Atur kartu, or a subcategory in Kelola subkategori): moves it one place later.")
                        }
                    }
                }
            }
            .onMove { source, destination in
                move(section, source, destination)
            }
        } header: {
            if let group = section.group {
                Text(group.title)
            }
        } footer: {
            if section.id == sections.last?.id {
                Text(
                    "Urutan di sini sama dengan urutan saat mencatat. Ketuk Edit untuk menyeretnya.",
                    comment: "Kelola subkategori: footer under the last visible section. The order is the add sheet's order; the Edit button turns on dragging."
                )
            }
        }
    }

    private var hiddenSection: some View {
        Section {
            ForEach(hidden) { subcategory in
                HStack(spacing: 12) {
                    row(for: subcategory)
                    Button {
                        unhide(subcategory)
                    } label: {
                        Text("Tampilkan", comment: "Kelola subkategori: button on a hidden subcategory that shows it again (not pinned again, D-049).")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .tint(Color(.brand))
                    .fixedSize()
                    .accessibilityIdentifier("subcategories.unhide.\(subcategory.name)")
                }
                .listRowBackground(Color(.surface))
                // A container, so the row's identifier doesn't replace the Tampilkan button's.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("subcategories.hidden.\(subcategory.name)")
            }
        } header: {
            Text("Tersembunyi", comment: "Kelola subkategori: header of the section of hidden subcategories.")
        } footer: {
            Text(
                "Subkategori yang sudah punya catatan disembunyikan, bukan dihapus, supaya riwayatnya tetap ada.",
                comment: "Kelola subkategori: footer of the hidden section. Subcategories with history are hidden instead of deleted so their history stays (D-006)."
            )
        }
    }

    /// Emoji, name, budget when set, pin glyph when pinned. At accessibility sizes the emoji goes above the
    /// name, so the name keeps the row's width; a name shrinks rather than breaking mid-word (one word, D-007).
    private func row(for subcategory: Subcategory) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return HStack(spacing: 8) {
            layout {
                Text(verbatim: subcategory.emoji)
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: subcategory.name)
                        .font(.body)
                        .foregroundStyle(Color(.textPrimary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if let budget = subcategory.monthlyBudget {
                        Text(LocalizedStringResource(
                            "subcategories.row.budget",
                            defaultValue: "Anggaran \(budget.rupiahFormatted)",
                            comment: "Kelola subkategori: a row's monthly budget, e.g. 'Anggaran Rp300.000'. The placeholder is the amount."
                        ))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Color(.textSecondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    }
                }
            }
            Spacer(minLength: 0)
            if subcategory.isPinned {
                Image(systemName: "pin.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityLabel(Text("Di Beranda", comment: "VoiceOver label of the pin glyph on a Kelola subkategori row: the subcategory is pinned on Home."))
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Writes

    private var ledger: Ledger {
        Ledger(context: context, timeZone: .autoupdatingCurrent)
    }

    private func move(_ section: SubcategorySection, from index: Int, to destination: Int) {
        move(section, IndexSet(integer: index), destination)
    }

    private func move(_ section: SubcategorySection, _ source: IndexSet, _ destination: Int) {
        do {
            try ledger.moveSubcategories(kind: section.kind, group: section.group, fromOffsets: source, toOffset: destination)
        } catch {
            SettingsLog.logger.error("Reordering subcategories failed: \(error.localizedDescription, privacy: .public)")
            showsSaveError = true
        }
    }

    private func unhide(_ subcategory: Subcategory) {
        do {
            try withAnimation {
                try ledger.unhide(subcategory)
            }
        } catch {
            SettingsLog.logger.error("Showing a subcategory failed: \(error.localizedDescription, privacy: .public)")
            showsSaveError = true
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SubcategoryListView()
    }
    .modelContainer(PreviewStore.makeContainer())
}
#endif
