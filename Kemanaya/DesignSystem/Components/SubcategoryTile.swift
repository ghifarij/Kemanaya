import SwiftUI

/// A compact subcategory button for the add sheet's grid (D-043, D-067): emoji over name on the
/// group's tinted surface, the same surface and text tokens as ``SubcategoryCard`` (D-040).
///
/// A tap only selects the tile (single selection); the sheet's Simpan saves (D-067). Selected: a
/// `textPrimary` outline (contrast-checked against the screen background) plus a checkmark in the
/// tile's own content color, so selection never relies on color alone. The tiles are always enabled
/// except while the sheet is saving, when it disables them and they dim.
struct SubcategoryTile: View {
    let emoji: String
    let name: String
    let tint: CategoryTint
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var verticalPadding: CGFloat = 10
    @Environment(\.isEnabled) private var isEnabled
    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    init(
        emoji: String,
        name: String,
        tint: CategoryTint,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.emoji = emoji
        self.name = name
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(verbatim: emoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(verbatim: name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Color(tint.content))
            .background(Color(tint.surface), in: shape)
            .overlay {
                if isSelected {
                    shape.strokeBorder(Color(.textPrimary), lineWidth: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(tint.content))
                        .padding(6)
                        .accessibilityHidden(true)
                }
            }
            // Disabled controls are exempt from contrast rules (the sheet disables the grid while saving).
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(shape)
        }
        .buttonStyle(.springy)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
        SubcategoryTile(emoji: "🍚", name: "Makan", tint: .kebutuhan, isSelected: true) {}
        SubcategoryTile(emoji: "📚", name: "Pendidikan", tint: .kebutuhan) {}
        SubcategoryTile(emoji: "☕", name: "Kopi", tint: .keinginan) {}
        SubcategoryTile(emoji: "💼", name: "Gaji", tint: .pemasukan, isSelected: true) {}
        SubcategoryTile(emoji: "🎁", name: "Hadiah", tint: .pemasukan) {}
        SubcategoryTile(emoji: "🍿", name: "Jajan", tint: .keinginan) {}.disabled(true)
    }
    .padding()
    .background(Color(.appBackground))
}
