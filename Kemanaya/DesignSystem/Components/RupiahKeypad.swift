import KemanayaCore
import SwiftUI

/// The rupiah keypad (D-013, D-044): `1 2 3 / 4 5 6 / 7 8 9 / 000 0 ⌫` (``KeypadInput/rows``), one
/// ``KeypadKey`` each. The add sheet and the budget sheet (D-062) share it; ``AmountEntry`` reduces the keys.
///
/// Each key is identified `<identifierPrefix>.0` … `.9`, `.000`, `.backspace` for UI tests.
struct RupiahKeypad: View {
    let identifierPrefix: String
    let onPress: (KeypadInput) -> Void

    init(identifierPrefix: String, onPress: @escaping (KeypadInput) -> Void) {
        self.identifierPrefix = identifierPrefix
        self.onPress = onPress
    }

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(KeypadInput.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        KeypadKey(key) { onPress(key) }
                            .accessibilityIdentifier(identifier(for: key))
                    }
                }
            }
        }
    }

    private func identifier(for key: KeypadInput) -> String {
        switch key {
        case .digit(let digit): "\(identifierPrefix).\(digit)"
        case .tripleZero: "\(identifierPrefix).000"
        case .backspace: "\(identifierPrefix).backspace"
        }
    }
}

#Preview {
    RupiahKeypad(identifierPrefix: "preview.key") { _ in }
        .padding()
        .background(Color(.appBackground))
}
