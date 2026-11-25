import KemanayaCore
import SwiftUI

/// A subcategory Riwayat's filter offers (D-074): one with a transaction in the 13-month window.
struct HistoryFilterOption: Identifiable, Hashable {
    let id: UUID
    /// User data, shown as typed (D-023).
    let name: String
    let emoji: String
    let section: PinSection
}

/// Riwayat's filter sheet (D-074, D-075), laid out like Mail's filter list and Settings: an inset-grouped
/// list of checkmark rows. "Jenis" holds Kebutuhan, Keinginan and Pemasukan; then one section of
/// subcategories per **ticked** group, only the ones used in the window. With no group ticked, only Jenis
/// shows. A ticked group with no subcategory picked means all of that group; picks narrow only their own
/// group, and unticking a group drops its picks.
///
/// It opens at full height only (D-075): a Cancel / Apply task whose sections grow as groups are ticked,
/// like Calendar's new event. A single large detent shows no grabber, as Apple's full-height sheets do.
///
/// It edits a draft of the applied filter: **Terapkan** applies it and closes, **Batal** closes and
/// discards it. While the draft differs from the applied filter, a swipe can't close the sheet, so no
/// picks are lost by accident. "Hapus pilihan" clears the draft only.
struct HistoryFilterSheet: View {
    let applied: HistoryFilter
    /// The subcategories to offer, in grid order (D-043).
    let options: [HistoryFilterOption]
    let onApply: (HistoryFilter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: HistoryFilter

    init(applied: HistoryFilter, options: [HistoryFilterOption], onApply: @escaping (HistoryFilter) -> Void) {
        self.applied = applied
        self.options = options
        self.onApply = onApply
        _draft = State(initialValue: applied)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PinSection.allCases, id: \.self) { section in
                        groupRow(section)
                    }
                } header: {
                    Text(LocalizedStringResource(
                        "history.filter.kinds",
                        defaultValue: "Jenis",
                        comment: "Riwayat filter sheet (D-074): header of the section listing Kebutuhan, Keinginan and Pemasukan."
                    ))
                }
                ForEach(draft.offeredSections, id: \.self) { section in
                    let items = options.filter { $0.section == section }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { option in
                                subcategoryRow(option)
                            }
                        } header: {
                            Text(
                                "Subkategori \(String(localized: section.title))",
                                comment: "Riwayat filter sheet (D-074): header of a section of subcategories, e.g. 'Subkategori Keinginan' ('Keinginan subcategories'). The placeholder is Kebutuhan, Keinginan or Pemasukan."
                            )
                        }
                    }
                }
                Section {
                    Button {
                        draft = HistoryFilter()
                    } label: {
                        Text("Hapus pilihan", comment: "Riwayat filter sheet (D-074): clears every row ticked in the sheet, without applying or closing it.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(draft.isEmpty)
                    .listRowBackground(Color(.surface))
                    .accessibilityIdentifier("history.filterReset")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.appBackground).ignoresSafeArea())
            .foregroundStyle(Color(.textPrimary))
            .tint(Color(.brand))
            .navigationTitle(Text("Filter", comment: "Riwayat (D-074): the filter sheet's title and the VoiceOver label of the toolbar button that opens it."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Batal", comment: "Cancels: closes a sheet or dialog without saving, deleting or restoring (the add sheet, the delete dialogs, the restore alert, the budget sheet and the subcategory editor).")
                    }
                    .accessibilityIdentifier("history.filterCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onApply(draft)
                        dismiss()
                    } label: {
                        Text("Terapkan", comment: "Riwayat filter sheet (D-074): applies the ticked filters to the list and closes the sheet.")
                    }
                    .accessibilityIdentifier("history.filterApply")
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(draft != applied)
        .accessibilityIdentifier("history.filterSheet")
    }

    private func groupRow(_ section: PinSection) -> some View {
        CheckRow(isOn: draft.groups.contains(section), identifier: "history.filter.group.\(section.rawValue)") {
            draft = draft.toggling(section)
        } mark: {
            GroupDot(section: section)
        } title: {
            Text(section.title)
        }
    }

    private func subcategoryRow(_ option: HistoryFilterOption) -> some View {
        CheckRow(isOn: draft.picks(in: option.section).contains(option.id), identifier: "history.filter.subcategory.\(option.name)") {
            draft = draft.toggling(subcategory: option.id, in: option.section)
        } mark: {
            Text(verbatim: option.emoji)
                .accessibilityHidden(true)
        } title: {
            Text(verbatim: option.name)
        }
    }
}

/// A group's colour dot (CategoryTint), the mark beside Kebutuhan, Keinginan and Pemasukan.
struct GroupDot: View {
    let section: PinSection

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(Color(CategoryTint(kind: section.kind, group: section.group).chartMark))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// One checkmark row: a leading mark, the title, and a checkmark while on. The whole row toggles; VoiceOver
/// reads it as a button with the Selected trait while on.
private struct CheckRow<Mark: View, Title: View>: View {
    let isOn: Bool
    let identifier: String
    let action: () -> Void
    @ViewBuilder let mark: Mark
    @ViewBuilder let title: Title

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                mark
                title
                    .foregroundStyle(Color(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.brand))
                    .opacity(isOn ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.surface))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview("Some picks") {
    let makan = UUID(), kopi = UUID(), jajan = UUID(), gaji = UUID()
    let options = [
        HistoryFilterOption(id: makan, name: "Makan", emoji: "🍚", section: .kebutuhan),
        HistoryFilterOption(id: UUID(), name: "Transportasi umum ke kantor", emoji: "🚌", section: .kebutuhan),
        HistoryFilterOption(id: kopi, name: "Kopi", emoji: "☕", section: .keinginan),
        HistoryFilterOption(id: jajan, name: "Jajan", emoji: "🍩", section: .keinginan),
        HistoryFilterOption(id: gaji, name: "Gaji", emoji: "💼", section: .pemasukan),
    ]
    // The sheet's content on its own: a presented sheet snapshots mid-animation in the canvas.
    HistoryFilterSheet(
        applied: HistoryFilter([.keinginan: [kopi], .pemasukan: []]),
        options: options
    ) { _ in }
}

#Preview("Nothing picked") {
    let options = [
        HistoryFilterOption(id: UUID(), name: "Makan", emoji: "🍚", section: .kebutuhan),
        HistoryFilterOption(id: UUID(), name: "Kopi", emoji: "☕", section: .keinginan),
        HistoryFilterOption(id: UUID(), name: "Gaji", emoji: "💼", section: .pemasukan),
    ]
    HistoryFilterSheet(
        applied: HistoryFilter(),
        options: options
    ) { _ in }
}
#endif
