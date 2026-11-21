import KemanayaCore
import SwiftUI

/// Every design-system piece on one scrolling page, for review on each simulator.
/// Shown instead of the tab bar when the app is launched with `-gallerySection` (D-043).
///
/// Screenshots can't scroll, so the launch argument `-gallerySection <name>` scrolls a section's
/// header to the top on appear, with `<name>` one of `cards | split | keypad | glass | type | colors | mascot`.
/// `UserDefaults` reads `-key value` launch arguments, so no parsing is needed here.
struct DesignGalleryView: View {
    enum GallerySection: String, CaseIterable {
        case cards, split, keypad, glass, type, colors, mascot

        var title: String {
            switch self {
            case .cards: "Kartu"
            case .split: "SplitBar"
            case .keypad: "Keypad"
            case .glass: "Glass"
            case .type: "Tipografi"
            case .colors: "Warna"
            case .mascot: "Si Naya"
            }
        }

        /// True when the app was launched with `-gallerySection`, whatever its value.
        static var isRequested: Bool {
            UserDefaults.standard.string(forKey: "gallerySection") != nil
        }

        /// The section named by `-gallerySection`, if any.
        static var fromLaunchArguments: GallerySection? {
            UserDefaults.standard.string(forKey: "gallerySection").flatMap(GallerySection.init(rawValue:))
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var entry = AmountEntry(amount: 45_000)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    section(.cards) { cards }
                    section(.split) { splitBars }
                    section(.keypad) { keypad }
                    section(.glass) { glassSample }
                    section(.type) { typeSamples }
                    section(.colors) { swatches }
                    section(.mascot) { mascot }
                }
                .padding(16)
            }
            .onAppear {
                if let target = GallerySection.fromLaunchArguments {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
        .foregroundStyle(Color(.textPrimary))
        .background(Color(.appBackground).ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: AppInfo.name)
                .font(.brandTitle)
                .accessibilityIdentifier("root.title")
            Text("Kemana ya uangku?", comment: "App tagline: 'Where did my money go?'")
                .foregroundStyle(Color(.textSecondary))
        }
    }

    private func section(_ section: GallerySection, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: section.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .id(section)
    }

    private var swatches: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 240 : 150))], spacing: 8) {
            ForEach(GallerySample.colorTokens, id: \.name) { token in
                HStack(spacing: 8) {
                    let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
                    shape
                        .fill(Color(token.color))
                        .overlay { shape.strokeBorder(Color(.textSecondary).opacity(0.3), lineWidth: 1) }
                        .frame(width: 32, height: 32)
                    Text(verbatim: token.name)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Si Naya's moods (D-063) on the app background, small sizes, and on the brand violet.
    private var mascot: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(SiNaya.Mood.allCases, id: \.self) { mood in
                    VStack(spacing: 4) {
                        SiNaya(mood: mood)
                            .frame(maxWidth: 120)
                        Text(verbatim: "\(mood)")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color(.textSecondary))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 16) {
                ForEach(SiNaya.Mood.allCases, id: \.self) { mood in
                    SiNaya(mood: mood).frame(width: 48, height: 48)
                }
                Spacer(minLength: 0)
                SiNaya(mood: .curious)
                    .frame(width: 72, height: 72)
                    .padding(14)
                    .background(Color(.brand), in: .rect(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var typeSamples: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Judul tebal bulat").font(.brandTitle)
            AmountText(1_250_000, size: .hero)
            AmountText(1_250_000, size: .large)
            AmountText(312_000, size: .medium)
            AmountText(-45_000, size: .small)
            Text(verbatim: "Bulan ini kamu paling banyak di Kopi ☕").font(.body)
            Text(verbatim: "Teks sekunder untuk keterangan").font(.subheadline).foregroundStyle(Color(.textSecondary))
        }
    }

    /// Home's pinned layout (D-068): a Kebutuhan and a Keinginan column of compact cards (one with an
    /// empty column's placeholder next to it), then the income rows.
    private var cards: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return VStack(alignment: .leading, spacing: 16) {
            layout {
                column(GallerySample.kebutuhanCards)
                column(GallerySample.keinginanCards)
            }
            layout {
                column(Array(GallerySample.kebutuhanCards.prefix(1)))
                PinPlaceholderCard {}
                    .frame(maxWidth: .infinity)
            }
            PinnedIncomeBlock {
                ForEach(GallerySample.incomeRows) { sample in
                    PinnedIncomeRow(emoji: sample.emoji, name: sample.name, thisMonth: sample.thisMonth) {
                    } contextMenu: {
                        sampleMenu
                    }
                }
            }
        }
    }

    private func column(_ samples: [GallerySample]) -> some View {
        VStack(spacing: 12) {
            ForEach(samples) { sample in
                SubcategoryCard(
                    emoji: sample.emoji,
                    name: sample.name,
                    tint: sample.tint,
                    thisMonth: sample.thisMonth,
                    lastMonth: sample.lastMonth,
                    budget: sample.budget
                ) {
                } contextMenu: {
                    sampleMenu
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Sample of D-012's menu: Lihat detail · Ubah · Lepas pin.
    @ViewBuilder private var sampleMenu: some View {
        sampleMenuItem("Lihat detail", systemImage: "chart.pie")
        sampleMenuItem("Ubah", systemImage: "pencil")
        sampleMenuItem("Lepas pin", systemImage: "pin.slash")
    }

    private func sampleMenuItem(_ title: String, systemImage: String) -> some View {
        Button {} label: {
            Label { Text(verbatim: title) } icon: { Image(systemName: systemImage) }
        }
    }

    private var splitBars: some View {
        VStack(alignment: .leading, spacing: 20) {
            SplitBar(kebutuhan: 3_420_000, keinginan: 1_180_000)
            SplitBar(kebutuhan: 2_000, keinginan: 1_500_000)
            SplitBar(kebutuhan: 0, keinginan: 0)
        }
        .padding(16)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    private var keypad: some View {
        VStack(spacing: 12) {
            AmountText(entry.amount, size: .hero)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(KeypadInput.rows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { kind in
                            KeypadKey(kind) { entry.press(kind) }
                        }
                    }
                }
            }
        }
    }

    private var glassSample: some View {
        ZStack {
            HStack(spacing: -24) {
                Circle().fill(Color(.kebutuhan))
                Circle().fill(Color(.keinginan))
                Circle().fill(Color(.pemasukan))
            }
            .frame(height: 120)
            Text(verbatim: "Liquid Glass")
                .font(.brandTitle)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .kemanayaGlass(in: .capsule)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DesignGalleryView()
}
