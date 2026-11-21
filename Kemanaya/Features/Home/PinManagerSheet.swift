import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// Atur kartu (D-048, D-068): every visible subcategory with a pin toggle, in three sections, Kebutuhan,
/// Keinginan and Pemasukan, the Home sections. In each, the pinned ones sit on top in Home order and drag
/// to reorder within the section; the unpinned follow in grid order. Each header counts the section's pins
/// against its limit ("3 dari 6") and each footer states the limit. Every change saves at once through
/// ``Ledger``, so Home updates behind the sheet.
///
/// A pin past a section's limit is refused (D-068): the toggle stays off, a warning haptic plays and a
/// short note appears at the bottom; VoiceOver hears the same note.
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
    /// The section whose limit the last refused pin hit.
    @State private var refusedSection = PinSection.kebutuhan
    @State private var showsLimitNote = false
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
            AccessibilityNotification.Announcement(limitMessage).post()
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
            // At accessibility sizes the count goes under the name, so neither word breaks mid-word.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
            layout {
                Text(section.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                Text(
                    "\(pinned.count) dari \(section.limit)",
                    comment: "Pin management: a section header's count, e.g. '3 dari 6': pinned now out of the section's limit (D-068)."
                )
                .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pins.header.\(section.rawValue)")
        } footer: {
            Text(
                "Maksimal \(section.limit) di Beranda. Seret untuk mengubah urutan.",
                comment: "Pin management: a section footer. The placeholder is the section's pin limit (6 for Kebutuhan and Keinginan, 3 for Pemasukan, D-068); pinned rows drag to reorder."
            )
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

    /// The note shown after a refused pin, on glass above the list's bottom edge.
    private var limitNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "pin.slash")
                .accessibilityHidden(true)
            Text(limitMessage)
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

    private var limitMessage: String {
        String(
            localized: "Maksimal \(refusedSection.limit) \(String(localized: refusedSection.title)) di Beranda. Lepas satu dulu untuk menambah yang lain.",
            comment: "Pin management: note shown when a pin past a section's limit is refused (D-068). 1: the limit (6 or 3), 2: the section, Kebutuhan, Keinginan or Pemasukan."
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
            } catch PinError.limitReached(let section) {
                refusedSection = section
                refusedCount += 1
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
