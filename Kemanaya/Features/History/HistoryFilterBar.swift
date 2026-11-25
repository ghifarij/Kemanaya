import KemanayaCore
import SwiftUI

/// The applied filter above Riwayat's list (D-074, D-075): one removable chip per ticked group and picked
/// subcategory ("Keinginan ✕", "☕ Kopi ✕"), then "Hapus semua". It scrolls sideways when the chips
/// don't fit, so no name is ever cut (D-071). A chip removes just its item at once; removing a group also
/// drops its picks, as in the sheet, and removing a group's last pick shows all of that group again.
struct HistoryFilterBar: View {
    let filter: HistoryFilter
    /// The picked subcategories that still exist, in grid order.
    let subcategories: [HistoryFilterOption]
    let onRemoveGroup: (PinSection) -> Void
    let onRemoveSubcategory: (UUID) -> Void
    let onClearAll: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(PinSection.allCases.filter(filter.groups.contains), id: \.self) { section in
                    FilterChip(name: Text(section.title), nameForLabel: String(localized: section.title)) {
                        onRemoveGroup(section)
                    } mark: {
                        GroupDot(section: section)
                    }
                }
                ForEach(subcategories) { option in
                    FilterChip(name: Text(verbatim: option.name), nameForLabel: option.name) {
                        onRemoveSubcategory(option.id)
                    } mark: {
                        Text(verbatim: option.emoji)
                            .accessibilityHidden(true)
                    }
                }
                Button(action: onClearAll) {
                    Text("Hapus semua", comment: "Riwayat (D-074): the text button at the end of the applied filters that clears them all.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.brand))
                        .fixedSize()
                        .padding(.horizontal, 4)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("history.clearFilters")
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .background(Color(.appBackground))
    }
}

/// "Keinginan ⓧ": a capsule on the surface colour; the whole 44 pt tall chip removes it.
private struct FilterChip<Mark: View>: View {
    let name: Text
    /// The name as plain text, for "Hapus filter Keinginan".
    let nameForLabel: String
    let action: () -> Void
    @ViewBuilder let mark: Mark

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                mark
                name
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.textPrimary))
                    .fixedSize()
                Image(systemName: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityHidden(true)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .background(Color(.surface), in: .capsule)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Hapus filter \(nameForLabel)",
            comment: "Riwayat (D-074): VoiceOver label of an applied-filter chip; tapping removes that filter. The placeholder is Kebutuhan, Keinginan, Pemasukan or a subcategory's name."
        ))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("history.filterChip")
    }
}

#if DEBUG
#Preview {
    let kopi = HistoryFilterOption(id: UUID(), name: "Kopi", emoji: "☕", section: .keinginan)
    let gaji = HistoryFilterOption(id: UUID(), name: "Gaji bulanan", emoji: "💼", section: .pemasukan)
    VStack(spacing: 0) {
        HistoryFilterBar(
            filter: HistoryFilter([.keinginan: [kopi.id], .pemasukan: [gaji.id]]),
            subcategories: [kopi, gaji],
            onRemoveGroup: { _ in },
            onRemoveSubcategory: { _ in },
            onClearAll: {}
        )
        HistoryFilterBar(
            filter: HistoryFilter(groups: [.kebutuhan]),
            subcategories: [],
            onRemoveGroup: { _ in },
            onRemoveSubcategory: { _ in },
            onClearAll: {}
        )
        Spacer()
    }
    .background(Color(.appBackground))
}
#endif
