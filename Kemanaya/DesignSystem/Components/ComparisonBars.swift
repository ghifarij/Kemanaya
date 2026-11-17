import KemanayaCore
import SwiftUI

/// Two tiny bars on a card: this month (thick, group color) over last month (thin, quieter color).
/// Both are scaled to the larger month. Purely visual; the card's accessibility value says the same.
struct ComparisonBars: View {
    let comparison: MonthComparison
    let tint: CategoryTint

    @ScaledMetric(relativeTo: .caption) private var currentHeight: CGFloat = 8
    @ScaledMetric(relativeTo: .caption) private var previousHeight: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            bar(fraction: comparison.currentFraction, height: currentHeight, color: Color(tint.bar))
            bar(fraction: comparison.previousFraction, height: previousHeight, color: Color(tint.secondaryContent))
        }
        .accessibilityHidden(true)
    }

    private func bar(fraction: Double, height: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(Color(tint.content).opacity(0.1))
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        // A non-zero month always shows at least a dot.
                        .frame(width: fraction > 0 ? max(proxy.size.width * fraction, height) : 0)
                }
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(CategoryTint.allCases, id: \.self) { tint in
            ComparisonBars(comparison: MonthComparison(current: 80, previous: 100), tint: tint)
                .padding()
                .background(Color(tint.surface), in: .rect(cornerRadius: 16))
        }
    }
    .padding()
}
