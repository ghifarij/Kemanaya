import SwiftData
import SwiftUI

/// The root: a native tab bar (D-021, D-048, D-051) with **Beranda** (Home), **Riwayat** (this month's
/// transactions, D-043) and **Analisis** (breakdown and trends). Pengaturan arrives with Phase 10.
/// Launching with `-gallerySection <name>` shows the design gallery instead, for screenshots.
/// Home and the gallery keep the `root.title` identifier on their title for the UI tests.
struct RootView: View {
    enum Destination: Hashable {
        case home, history, analysis
    }

    @State private var selection = Destination.home

    var body: some View {
        if DesignGalleryView.GallerySection.isRequested {
            DesignGalleryView()
        } else {
            TabView(selection: $selection) {
                Tab(
                    String(localized: "Beranda", comment: "Tab bar: the Home tab, with the month's totals and pinned cards."),
                    systemImage: "house",
                    value: Destination.home
                ) {
                    HomeView()
                }
                Tab(
                    String(localized: "Riwayat", comment: "Tab bar: the history tab, this month's transactions."),
                    systemImage: "list.bullet",
                    value: Destination.history
                ) {
                    MonthListView()
                }
                Tab(
                    String(localized: "Analisis", comment: "Title of the Analisis tab and its tab bar item: spending breakdown and trends."),
                    systemImage: "chart.pie",
                    value: Destination.analysis
                ) {
                    AnalysisView()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    RootView()
        .modelContainer(PreviewStore.makeContainer())
}
#endif
