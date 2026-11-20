import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// Atur kartu (D-048): every visible subcategory with a pin toggle. Pinned ones sit on top in Home order
/// and drag to reorder; the rest follow by section (Kebutuhan, Keinginan, Pemasukan) in grid order.
/// Every change saves at once through ``Ledger``, so Home updates behind the sheet.
///
/// A 10th pin is refused (D-012): the toggle stays off, a warning haptic plays and a short note
/// appears at the bottom; VoiceOver hears the same note.
struct PinManagerSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Visible subcategories in grid order; pinned ones are picked out below.
    @Query(
        filter: #Predicate<Subcategory> { !$0.isHidden },
        sort: [SortDescriptor(\Subcategory.sortOrder), SortDescriptor(\Subcategory.name)]
    ) private var visible: [Subcategory]

    /// Bumped on each refused pin: shows the note and plays the haptic.
    @State private var refusedCount = 0
    @State private var showsLimitNote = false
    @State private var showsSaveError = false

    var body: some View {
        NavigationStack {
            List {
                pinnedSection
                ForEach(SubcategorySection.sections(from: unpinned, kinds: [.expense, .income])) { section in
                    unpinnedSection(section)
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
                        Text("Selesai", comment: "Closes the pin management sheet. Changes are already saved.")
                    }
                    .accessibilityIdentifier("pins.done")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showsLimitNote {
                    limitNote
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sensoryFeedback(.warning, trigger: refusedCount)
        .task(id: refusedCount) {
            guard refusedCount > 0 else { return }
            withAnimation { showsLimitNote = true }
            AccessibilityNotification.Announcement(Self.limitMessage).post()
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { showsLimitNote = false }
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

    private var pinned: [Subcategory] {
        visible.filter(\.isPinned).sorted { ($0.pinOrder ?? 0) < ($1.pinOrder ?? 0) }
    }

    private var unpinned: [Subcategory] {
        visible.filter { !$0.isPinned }
    }

    private var pinnedSection: some View {
        let pinned = pinned
        return Section {
            if pinned.isEmpty {
                Text("Belum ada kartu. Nyalakan kategori di bawah untuk menambahkannya ke Beranda.", comment: "Pin management: the pinned section when nothing is pinned.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                    .listRowBackground(Color(.surface))
            }
            // Identified apart from the same subcategory's row in its group section: a row that kept its
            // identity while moving into this section came without its reorder handle until reopened.
            ForEach(Array(pinned.enumerated()), id: \.element.pinnedRowID) { index, subcategory in
                row(for: subcategory)
                    .accessibilityActions {
                        if index > 0 {
                            Button {
                                move(from: index, to: index - 1)
                            } label: {
                                Text("Geser ke atas", comment: "VoiceOver action on a reorderable row (a pinned card in Atur kartu, or a subcategory in Kelola subkategori): moves it one place earlier.")
                            }
                        }
                        if index < pinned.count - 1 {
                            Button {
                                move(from: index, to: index + 2)
                            } label: {
                                Text("Geser ke bawah", comment: "VoiceOver action on a reorderable row (a pinned card in Atur kartu, or a subcategory in Kelola subkategori): moves it one place later.")
                            }
                        }
                    }
            }
            .onMove { source, destination in
                movePins(source, destination)
            }
        } header: {
            Text(
                "Di Beranda · \(pinned.count) dari \(SubcategoryRules.maximumPins)",
                comment: "Pin management: header of the pinned section. 1: cards pinned now, 2: the maximum (9)."
            )
            .accessibilityIdentifier("pins.header")
        } footer: {
            Text("Seret untuk mengubah urutan kartu.", comment: "Pin management: footer under the pinned cards, explaining drag to reorder.")
        }
    }

    /// Kebutuhan, Keinginan or Pemasukan, in grid order; ``SubcategorySection/sections(from:kinds:)`` drops empty ones.
    private func unpinnedSection(_ section: SubcategorySection) -> some View {
        Section {
            ForEach(section.subcategories) { subcategory in
                row(for: subcategory)
            }
        } header: {
            Text(section.group?.title ?? section.kind.title)
        }
    }

    private func row(for subcategory: Subcategory) -> some View {
        // At accessibility sizes the emoji goes above the name, so the name keeps the row's width;
        // a name shrinks rather than breaking mid-word (names are one word, D-007).
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return Toggle(isOn: pinBinding(for: subcategory)) {
            layout {
                Text(verbatim: subcategory.emoji)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(verbatim: subcategory.name)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .tint(Color(.brand))
        .listRowBackground(Color(.surface))
        .accessibilityIdentifier("pins.toggle.\(subcategory.name)")
    }

    /// The note shown after a refused 10th pin, on glass above the list's bottom edge.
    private var limitNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "pin.slash")
                .accessibilityHidden(true)
            Text(Self.limitMessage)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(.textPrimary))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kemanayaGlass(in: .rect(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pins.limitNote")
    }

    private static var limitMessage: String {
        String(
            localized: "Maksimal \(SubcategoryRules.maximumPins) kartu. Lepas satu dulu untuk menambah yang lain.",
            comment: "Pin management: note shown when a 10th pin is refused. The placeholder is the maximum (9)."
        )
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
            } catch PinError.limitReached {
                refusedCount += 1
            } catch {
                HomeLog.logger.error("Changing a pin failed: \(error.localizedDescription, privacy: .public)")
                showsSaveError = true
            }
        }
    }

    private func move(from index: Int, to destination: Int) {
        movePins(IndexSet(integer: index), destination)
    }

    private func movePins(_ source: IndexSet, _ destination: Int) {
        do {
            try ledger.movePins(fromOffsets: source, toOffset: destination)
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
