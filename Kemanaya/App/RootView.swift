import SwiftData
import SwiftUI

/// The root screen. Until Home arrives in Phase 5 it is this month's transaction list (D-043);
/// launching with `-gallerySection <name>` shows the design gallery instead, for screenshots.
/// Both keep the `root.title` identifier on their title for the UI tests.
struct RootView: View {
    var body: some View {
        if DesignGalleryView.GallerySection.isRequested {
            DesignGalleryView()
        } else {
            MonthListView()
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .modelContainer(PreviewStore.makeContainer())
}
#endif
