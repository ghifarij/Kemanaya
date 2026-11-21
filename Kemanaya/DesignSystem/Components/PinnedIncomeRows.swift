import KemanayaCore
import SwiftUI

/// One pinned income subcategory on Home (D-068): a thin, full-width, Settings-style row with the emoji
/// and name leading and this month's total trailing, "💼 Gaji ……… Rp8.500.000". Several rows sit in one
/// rounded block (``PinnedIncomeBlock``).
///
/// The emoji sits on a small lime disc, the Pemasukan accent as decoration only; the name and amount stay
/// in the text tokens (D-040). Tap runs `action` (a quick log); long-press shows the same menu as a card,
/// which is also offered to VoiceOver as actions.
struct PinnedIncomeRow<MenuItems: View>: View {
    let emoji: String
    let name: String
    let thisMonth: Int64
    let action: () -> Void
    let menuItems: () -> MenuItems

    @ScaledMetric(relativeTo: .body) private var discSize: CGFloat = 30

    init(
        emoji: String,
        name: String,
        thisMonth: Int64,
        action: @escaping () -> Void,
        @ViewBuilder contextMenu: @escaping () -> MenuItems
    ) {
        self.emoji = emoji
        self.name = name
        self.thisMonth = thisMonth
        self.action = action
        self.menuItems = contextMenu
    }

    var body: some View {
        Button(action: action) {
            // One line while name and amount fit; at large text the amount moves under the name.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    leading
                    Spacer(minLength: 8)
                    amount.fixedSize()
                }
                VStack(alignment: .leading, spacing: 6) {
                    leading
                    amount
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(String(
            localized: "\(thisMonth) rupiah bulan ini",
            comment: "VoiceOver value of a Home card or income row, first part: this month's total in whole rupiah."
        )))
        .contentShape(.contextMenuPreview, .rect)
        .contextMenu { menuItems() }
        .accessibilityActions { menuItems() }
    }

    private var leading: some View {
        HStack(spacing: 12) {
            Text(verbatim: emoji)
                .font(.body)
                .frame(width: discSize, height: discSize)
                .background(Color(.pemasukan), in: .circle)
            Text(verbatim: name)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var amount: some View {
        AmountText(thisMonth, size: .small)
            .foregroundStyle(Color(.textPrimary))
    }
}

/// The rounded block that holds Home's income rows, with hairlines between them (D-068).
struct PinnedIncomeBlock<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider().padding(.leading, 14)
                    }
                    row
                }
            }
        }
        .background(Color(.surface), in: .rect(cornerRadius: 20, style: .continuous))
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
    }
}

/// A Settings-style press: the row's background darkens a little while held.
private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(.textPrimary).opacity(configuration.isPressed ? 0.08 : 0))
    }
}

/// The dashed "＋ Pin" card in an empty Home column (D-068): opens Atur so the group gets its first pin.
struct PinPlaceholderCard: View {
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var padding: CGFloat = 14
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        Button(action: action) {
            Label {
                Text("Pin", comment: "Home: the dashed placeholder in an empty Kebutuhan or Keinginan column, shown as '+ Pin'; it opens Atur to pin a subcategory there (D-068).")
            } icon: {
                Image(systemName: "plus")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(.textSecondary))
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: 88)
            .overlay {
                shape.strokeBorder(Color(.textSecondary).opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            }
            .contentShape(shape)
        }
        .buttonStyle(.springy)
    }
}

#Preview {
    VStack(spacing: 16) {
        PinnedIncomeBlock {
            PinnedIncomeRow(emoji: "💼", name: "Gaji", thisMonth: 8_500_000) {} contextMenu: {}
            PinnedIncomeRow(emoji: "🎁", name: "Bonus", thisMonth: 0) {} contextMenu: {}
        }
        PinPlaceholderCard {}
            .frame(width: 170)
    }
    .padding()
    .background(Color(.appBackground))
}
