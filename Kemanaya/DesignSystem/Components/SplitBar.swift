import KemanayaCore
import SwiftUI

/// Kebutuhan vs Keinginan as one proportional bar with a legend of percentages (D-014): the yearly recap.
/// Purely descriptive: no color or copy suggests either side is good or bad (D-022).
struct SplitBar: View {
    let share: SplitShare

    @ScaledMetric(relativeTo: .body) private var barHeight: CGFloat = 16

    init(kebutuhan: Int64, keinginan: Int64) {
        share = SplitShare(first: kebutuhan, second: keinginan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bar
            legend
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Kebutuhan dan Keinginan",
            comment: "VoiceOver label for the bar that splits spending into needs and wants."
        ))
        .accessibilityValue(Text(accessibilityValue))
    }

    private var bar: some View {
        SplitTrack(share: share, height: barHeight)
    }

    /// Picks the widest layout that fits, so a word never splits: both items on one row,
    /// then one item per row, then the percentage under its name.
    private var legend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { legendItems(percentOnOwnLine: false) }
            VStack(alignment: .leading, spacing: 4) { legendItems(percentOnOwnLine: false) }
            VStack(alignment: .leading, spacing: 8) { legendItems(percentOnOwnLine: true) }
        }
        .font(.subheadline)
    }

    @ViewBuilder private func legendItems(percentOnOwnLine: Bool) -> some View {
        let percentages = share.percentages
        legendItem(
            Text(ExpenseGroup.kebutuhan.title),
            percent: percentages.first, tint: .kebutuhan, percentOnOwnLine: percentOnOwnLine
        )
        legendItem(
            Text(ExpenseGroup.keinginan.title),
            percent: percentages.second, tint: .keinginan, percentOnOwnLine: percentOnOwnLine
        )
    }

    private func legendItem(_ title: Text, percent: Int, tint: CategoryTint, percentOnOwnLine: Bool) -> some View {
        let layout = percentOnOwnLine
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            HStack(spacing: 6) {
                Circle().fill(Color(tint.bar)).frame(width: 10, height: 10)
                title
                    .foregroundStyle(Color(.textSecondary))
                    // Last resort on the narrowest screens: shrink, never split the word.
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(percent, format: .percent)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color(.textPrimary))
                .lineLimit(1)
        }
    }

    private var accessibilityValue: String {
        guard !share.isEmpty else { return String(
            localized: "Belum ada pengeluaran",
            comment: "VoiceOver value for the needs/wants bar when nothing has been spent yet."
        ) }
        let percentages = share.percentages
        return String(
            localized: "Kebutuhan \(percentages.first) persen, Keinginan \(percentages.second) persen",
            comment: "VoiceOver value for the needs/wants bar. 1: needs share in percent, 2: wants share in percent; they add up to 100."
        )
    }
}

/// The bar alone (D-014, D-073): Kebutuhan's Strong colour from the left and Keinginan's from the right,
/// each as wide as its share; one side takes the whole width when the other is zero, and nothing spent
/// leaves an empty track. A tiny share stays visible as a round dot. Purely visual: callers carry the
/// numbers for VoiceOver. ``SplitBar`` and the Home hero (D-073) use it.
struct SplitTrack: View {
    let share: SplitShare
    let height: CGFloat

    private let gap: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let widths = share.segmentWidths(totalWidth: proxy.size.width, gap: gap, minimumWidth: height)
            if share.isEmpty {
                Capsule().fill(Color(.textSecondary).opacity(0.2))
            } else {
                HStack(spacing: widths.first > 0 && widths.second > 0 ? gap : 0) {
                    Capsule().fill(Color(CategoryTint.kebutuhan.bar)).frame(width: widths.first)
                    Capsule().fill(Color(CategoryTint.keinginan.bar)).frame(width: widths.second)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        SplitBar(kebutuhan: 3_200_000, keinginan: 1_100_000)
        SplitBar(kebutuhan: 1, keinginan: 4_000_000)
        SplitBar(kebutuhan: 900_000, keinginan: 0)
        SplitBar(kebutuhan: 0, keinginan: 0)
    }
    .padding()
    .background(Color(.surface))
}
