import SwiftUI

/// Si Naya at a fixed, modest size for an empty state, onboarding or the store error screen (D-022, D-063).
///
/// Decorative, so it doesn't grow with Dynamic Type: at the accessibility sizes it shrinks to three
/// quarters, at most 72 pt, leaving the room to the text it sits with.
struct EmptyStateMascot: View {
    let mood: SiNaya.Mood
    /// The side at the standard text sizes.
    var size: CGFloat = 64

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The largest side at the accessibility sizes, where the text needs the height.
    private static let accessibilityMaximum: CGFloat = 72

    var body: some View {
        let side = dynamicTypeSize.isAccessibilitySize ? min((size * 0.75).rounded(), Self.accessibilityMaximum) : size
        SiNaya(mood: mood)
            .frame(width: side, height: side)
    }
}

#Preview {
    HStack(spacing: 16) {
        EmptyStateMascot(mood: .calm)
        EmptyStateMascot(mood: .curious, size: 96)
        EmptyStateMascot(mood: .sleepy, size: 120)
    }
    .padding()
    .background(Color(.appBackground))
}
