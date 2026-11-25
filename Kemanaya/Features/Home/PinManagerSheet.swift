import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// Atur kartu (D-048, D-068): every visible subcategory with a pin toggle, in three sections, Kebutuhan,
/// Keinginan and Pemasukan, the Home sections. In each, the pinned ones sit on top in Home order and drag
/// to reorder within the section; the unpinned follow in grid order. Every change saves at once through
/// ``Ledger``, so Home updates behind the sheet.
///
/// A section takes any number of pins (D-079, which dropped D-068's 6 / 6 / 3), so there is no count, no
/// limit and no refused pin.
///
/// Pins only: budgets are set on the Anggaran sheet or from a card's menu (D-077).
struct PinManagerSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Visible subcategories in grid order; pinned ones are picked out below.
    @Query(
        filter: #Predicate<Subcategory> { !$0.isHidden },
        sort: [SortDescriptor(\Subcategory.sortOrder), SortDescriptor(\Subcategory.name)]
    ) private var visible: [Subcategory]

    @State private var showsSaveError = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(PinSection.allCases, id: \.self) { section in
                    pinSection(section)
                }
            }
            // Always in edit mode, so pinned rows show their reorder handles; toggles still work.
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color(.appBackground).ignoresSafeArea())
            .foregroundStyle(Color(.textPrimary))
            .accessibilityIdentifier("pins.list")
            .navigationTitle(Text("Atur kartu", comment: "Title of the pin management sheet, and VoiceOver label of the Atur button that opens it."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(BudgetCopy.done)
                    }
                    .accessibilityIdentifier("pins.done")
                }
            }
        }
        .alert(
            Text("Perubahan kartu belum tersimpan", comment: "Alert title in pin management when saving a pin, unpin or reorder failed and trying again may work."),
            isPresented: $showsSaveError
        ) {
            Button {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: {
            Text("Coba ubah sekali lagi ya.", comment: "Alert message when saving a change failed (a pin, the order of cards or subcategories, or Tampilkan): asks to try again.")
        }
    }

    // MARK: - Sections

    /// One Home section (D-068): its pinned subcategories in Home order (reorderable), then the rest in
    /// grid order.
    private func pinSection(_ section: PinSection) -> some View {
        let members = visible.filter { $0.pinSection == section }
        let pinned = members.filter(\.isPinned).sorted { ($0.pinOrder ?? 0) < ($1.pinOrder ?? 0) }
        let unpinned = members.filter { !$0.isPinned }
        return Section {
            // Identified apart from the same subcategory's unpinned row: a row that kept its identity
            // while moving into the pinned rows came without its reorder handle until reopened.
            ForEach(Array(pinned.enumerated()), id: \.element.pinnedRowID) { index, subcategory in
                row(for: subcategory)
                    .accessibilityActions {
                        if index > 0 {
                            Button {
                                move(in: section, from: index, to: index - 1)
                            } label: {
                                Text("Geser ke atas", comment: "VoiceOver action on a reorderable row (a pinned card in Atur kartu, or a subcategory in Kelola subkategori): moves it one place earlier.")
                            }
                        }
                        if index < pinned.count - 1 {
                            Button {
                                move(in: section, from: index, to: index + 2)
                            } label: {
                                Text("Geser ke bawah", comment: "VoiceOver action on a reorderable row (a pinned card in Atur kartu, or a subcategory in Kelola subkategori): moves it one place later.")
                            }
                        }
                    }
            }
            .onMove { source, destination in
                movePins(in: section, source, destination)
            }
            ForEach(unpinned) { subcategory in
                row(for: subcategory)
            }
        } header: {
            header(for: section)
        } footer: {
            Text(
                "Seret kartu yang dipin untuk mengubah urutan.",
                comment: "Pin management: a section footer. Pinned rows drag to reorder within the section; there is no pin limit (D-079)."
            )
        }
    }

    // MARK: - Header

    /// The section's name, e.g. "Kebutuhan". No pin count: a section has no limit (D-079).
    private func header(for section: PinSection) -> some View {
        Text(section.title)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("pins.header.\(section.rawValue)")
            // As written, on both OS: iOS 18 would capitalise the header, VoiceOver's reading included.
            .textCase(nil)
    }

    // MARK: - Rows

    /// The emoji and name, then the pin toggle.
    private func row(for subcategory: Subcategory) -> some View {
        HStack(spacing: 12) {
            rowName(subcategory)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityHidden(true)
            Toggle(isOn: pinBinding(for: subcategory)) {
                Text(verbatim: subcategory.displayName)
            }
            .labelsHidden()
            .fixedSize()
            .tint(Color(.brand))
            .accessibilityIdentifier("pins.toggle.\(subcategory.name)")
        }
        .listRowBackground(Color(.surface))
    }

    /// The emoji and name. At accessibility sizes the emoji goes above the name, so the name keeps the
    /// row's width; a name shrinks rather than breaking mid-word (names are one word, D-007).
    private func rowName(_ subcategory: Subcategory) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(verbatim: subcategory.emoji)
                .font(.title3)
                .accessibilityHidden(true)
            Text(verbatim: subcategory.displayName)
                .font(.body)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    // MARK: - Writes

    private var ledger: Ledger {
        Ledger(context: context, timeZone: .autoupdatingCurrent)
    }

    private func pinBinding(for subcategory: Subcategory) -> Binding<Bool> {
        Binding {
            subcategory.isPinned
        } set: { isOn in
            do {
                try withAnimation {
                    if isOn {
                        try ledger.pin(subcategory)
                    } else {
                        try ledger.unpin(subcategory)
                    }
                }
            } catch {
                HomeLog.logger.error("Changing a pin failed: \(error.localizedDescription, privacy: .public)")
                showsSaveError = true
            }
        }
    }

    private func move(in section: PinSection, from index: Int, to destination: Int) {
        movePins(in: section, IndexSet(integer: index), destination)
    }

    private func movePins(in section: PinSection, _ source: IndexSet, _ destination: Int) {
        do {
            try ledger.movePins(in: section, fromOffsets: source, toOffset: destination)
        } catch {
            HomeLog.logger.error("Reordering pins failed: \(error.localizedDescription, privacy: .public)")
            showsSaveError = true
        }
    }
}

private extension Subcategory {
    /// The pinned section's row identity (see ``PinManagerSheet``).
    var pinnedRowID: String { "pinned-\(id.uuidString)" }
}

#if DEBUG
#Preview {
    PinManagerSheet()
        .modelContainer(PreviewStore.makeContainer())
}
#endif
