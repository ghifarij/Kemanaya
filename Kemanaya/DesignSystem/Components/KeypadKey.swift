import SwiftUI

/// One key of the rupiah keypad (D-013). The keypad layout itself comes in Phase 4.
struct KeypadKey: View {
    enum Kind: Hashable, Sendable {
        case digit(Int)
        case tripleZero
        case backspace
    }

    let kind: Kind
    let action: () -> Void

    /// Grows with Dynamic Type; never below the 44 pt minimum hit target.
    @ScaledMetric(relativeTo: .title) private var height: CGFloat = 56
    private let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    init(_ kind: Kind, action: @escaping () -> Void) {
        self.kind = kind
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
                .font(.amountLarge)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // Keeps "000" off the key edges at accessibility sizes: it shrinks instead.
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: max(height, 44))
                .foregroundStyle(Color(.textPrimary))
                .background(Color(.surface), in: shape)
                .contentShape(shape)
        }
        .buttonStyle(.springy)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isKeyboardKey)
    }

    @ViewBuilder private var label: some View {
        switch kind {
        case .digit(let digit): Text(verbatim: "\(digit)")
        case .tripleZero: Text(verbatim: "000")
        case .backspace: Image(systemName: "delete.left")
        }
    }

    private var accessibilityLabel: Text {
        switch kind {
        case .digit(let digit): Text(verbatim: "\(digit)")
        case .tripleZero: Text("Tiga nol", comment: "VoiceOver label for the keypad key that adds three zeros (000).")
        case .backspace: Text("Hapus", comment: "VoiceOver label for the keypad key that deletes the last digit.")
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        KeypadKey(.digit(7)) {}
        KeypadKey(.tripleZero) {}
        KeypadKey(.backspace) {}
    }
    .padding()
    .background(Color(.appBackground))
}
