import KemanayaCore
import SwiftUI

/// Every design-system piece on one scrolling page, for review on each simulator.
/// Temporary: it is the root screen until Home replaces it in Phase 5.
///
/// Screenshots can't scroll, so the launch argument `-gallerySection <name>` scrolls a section's
/// header to the top on appear, with `<name>` one of `cards | split | keypad | glass | type | colors`.
/// `UserDefaults` reads `-key value` launch arguments, so no parsing is needed here.
struct DesignGalleryView: View {
    enum GallerySection: String, CaseIterable {
        case cards, split, keypad, glass, type, colors

        var title: String {
            switch self {
            case .cards: "Kartu"
            case .split: "SplitBar"
            case .keypad: "Keypad"
            case .glass: "Glass"
            case .type: "Tipografi"
            case .colors: "Warna"
            }
        }

        /// The section named by `-gallerySection`, if any.
        static var fromLaunchArguments: GallerySection? {
            UserDefaults.standard.string(forKey: "gallerySection").flatMap(GallerySection.init(rawValue:))
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var typedAmount: Int64 = 45_000

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

    private var cards: some View {
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount), spacing: 12) {
            ForEach(GallerySample.pinnedCards) { sample in
                SubcategoryCard(
                    emoji: sample.emoji,
                    name: sample.name,
                    tint: sample.tint,
                    thisMonth: sample.thisMonth,
                    lastMonth: sample.lastMonth
                ) {
                } contextMenu: {
                    sampleMenuItem("Lihat detail", systemImage: "chart.bar")
                    sampleMenuItem("Edit", systemImage: "pencil")
                    sampleMenuItem("Lepas pin", systemImage: "pin.slash")
                }
            }
        }
    }

    /// Sample D-012 menu; the real actions arrive with Home in Phase 5.
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
            AmountText(typedAmount, size: .hero)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(Self.keyRows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { kind in
                            KeypadKey(kind) { press(kind) }
                        }
                    }
                }
            }
        }
    }

    private static let keyRows: [[KeypadKey.Kind]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.tripleZero, .digit(0), .backspace],
    ]

    /// Gallery-only input so the keys do something; the real keypad logic is Phase 4.
    private func press(_ kind: KeypadKey.Kind) {
        let cap: Int64 = 999_999_999_999
        switch kind {
        case .digit(let digit): typedAmount = min(typedAmount * 10 + Int64(digit), cap)
        case .tripleZero: typedAmount = min(typedAmount * 1_000, cap)
        case .backspace: typedAmount /= 10
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
