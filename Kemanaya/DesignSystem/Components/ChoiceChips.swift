import SwiftUI

/// Mutually exclusive choices as chips, e.g. Analisis's **Semua · Kebutuhan · Keinginan** filter and its
/// **Harian · Mingguan** switch (D-051). A content-layer control (D-021): unlike a segmented control,
/// it never truncates a label. The chips sit in a row, or in a column when the row doesn't fit (large
/// text sizes). VoiceOver reads each chip as a button, the chosen one with the Selected trait.
///
/// The chosen chip is `textPrimary` filled with `appBackground` text, the same pair as body text on the
/// background, inverted; the others are outlined. Neutral on purpose: no group colour, so no choice
/// looks better than another (D-022).
struct ChoiceChips<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: Text
        /// The chip's accessibility identifier, for UI tests.
        let identifier: String
    }

    let options: [Option]
    @Binding var selection: Value

    @ScaledMetric(relativeTo: .subheadline) private var horizontalPadding: CGFloat = 14

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) { chips }
        }
    }

    private var chips: some View {
        ForEach(options, id: \.value) { option in
            chip(option)
        }
    }

    private func chip(_ option: Option) -> some View {
        let isSelected = option.value == selection
        return Button {
            selection = option.value
        } label: {
            option.title
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .foregroundStyle(Color(isSelected ? .appBackground : .textPrimary))
                .background {
                    if isSelected {
                        Capsule().fill(Color(.textPrimary))
                    } else {
                        Capsule().strokeBorder(Color(.textSecondary).opacity(0.6), lineWidth: 1)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(option.identifier)
    }
}

#Preview {
    @Previewable @State var selection = 0
    ChoiceChips(
        options: [
            .init(value: 0, title: Text(verbatim: "Semua"), identifier: "a"),
            .init(value: 1, title: Text(verbatim: "Kebutuhan"), identifier: "b"),
            .init(value: 2, title: Text(verbatim: "Keinginan"), identifier: "c"),
        ],
        selection: $selection
    )
    .padding()
    .background(Color(.appBackground))
}
