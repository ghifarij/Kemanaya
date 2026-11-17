import SwiftUI

/// Temporary root screen: the design-system gallery (Phase 2).
/// Home replaces it in Phase 5 (D-012). The gallery keeps the `root.title` identifier for the UI test.
struct RootView: View {
    var body: some View {
        DesignGalleryView()
    }
}

#Preview {
    RootView()
}
