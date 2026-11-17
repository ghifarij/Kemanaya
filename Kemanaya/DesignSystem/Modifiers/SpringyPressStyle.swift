import SwiftUI

/// A springy squash on press for cards and keypad keys (D-022 motion).
/// With Reduce Motion on, the press dims instead of scaling.
struct SpringyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .scaleEffect(pressed && !reduceMotion ? 0.95 : 1)
            .opacity(pressed && reduceMotion ? 0.7 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.3, dampingFraction: 0.55),
                value: pressed
            )
    }
}

extension ButtonStyle where Self == SpringyPressStyle {
    /// A springy squash on press. See ``SpringyPressStyle``.
    static var springy: SpringyPressStyle { SpringyPressStyle() }
}

#Preview {
    Button {} label: {
        Text(verbatim: "Tekan aku")
            .font(.brandTitle)
            .padding(24)
            .background(Color(.kebutuhanSurface), in: .rect(cornerRadius: 24))
    }
    .buttonStyle(.springy)
    .foregroundStyle(Color(.textPrimary))
}
