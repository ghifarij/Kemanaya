import KemanayaCore
import SwiftUI

/// Placeholder root screen. Home replaces it in Phase 5 (D-012).
struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text(verbatim: AppInfo.name)
                .font(.largeTitle.bold())
                .accessibilityIdentifier("root.title")
            Text("Kemana ya uangku?")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

#Preview {
    RootView()
}
