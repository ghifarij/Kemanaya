import KemanayaCore
import SwiftUI

/// How much of a budget is used (D-010, D-041), as a bar (Home's group budgets) or a small ring
/// (a card's subcategory budget, so it can't be mistaken for the card's month bars).
///
/// Neutral on purpose (D-022, D-041): going over fills the meter in the same group color, with no red
/// and no alarm; the caption says "Lewat" plainly. Purely visual: the caller's text carries the numbers
/// for VoiceOver.
struct BudgetMeter: View {
    enum Style {
        /// A full-width bar.
        case bar
        /// A ring about the size of a caption line.
        case ring
    }

    let progress: BudgetProgress
    let tint: CategoryTint
    let style: Style

    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var ringSize: CGFloat = 16

    var body: some View {
        Group {
            switch style {
            case .bar: bar
            case .ring: ring
            }
        }
        .accessibilityHidden(true)
    }

    private var track: Color { Color(tint.content).opacity(0.1) }

    private var bar: some View {
        Capsule()
            .fill(track)
            .frame(height: barHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    let fraction = progress.clampedFraction
                    Capsule()
                        .fill(Color(tint.bar))
                        // Any spending shows at least a dot.
                        .frame(width: fraction > 0 ? max(proxy.size.width * fraction, barHeight) : 0)
                }
            }
    }

    private var ring: some View {
        let lineWidth = max(ringSize * 0.22, 3)
        return ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress.clampedFraction)
                .stroke(Color(tint.bar), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: ringSize, height: ringSize)
        .padding(lineWidth / 2)
    }
}

extension BudgetProgress {
    /// "Sisa Rp55.000", or "Lewat Rp36.500" once over: stated plainly, never praised or blamed (D-041).
    var statusText: Text {
        if isOverBudget {
            Text(
                "Lewat \((-remaining).rupiahFormatted)",
                comment: "Budget caption when spending went over the budget, e.g. 'Lewat Rp36.500'. Neutral: state it, never blame. The placeholder is the amount over."
            )
        } else {
            Text(
                "Sisa \(remaining.rupiahFormatted)",
                comment: "Budget caption: what is left of the budget this month, e.g. 'Sisa Rp55.000'. The placeholder is the amount left."
            )
        }
    }

    /// VoiceOver's reading of ``statusText``, with the budget, in whole rupiah.
    var accessibilityStatus: String {
        if isOverBudget {
            String(
                localized: "anggaran \(budget) rupiah, lewat \(-remaining) rupiah",
                comment: "VoiceOver: a budget and how far spending went over it, in whole rupiah. 1: the budget, 2: the amount over. Neutral, never blame."
            )
        } else {
            String(
                localized: "anggaran \(budget) rupiah, sisa \(remaining) rupiah",
                comment: "VoiceOver: a budget and what is left of it, in whole rupiah. 1: the budget, 2: the amount left."
            )
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        ForEach(CategoryTint.allCases, id: \.self) { tint in
            HStack(spacing: 12) {
                BudgetMeter(progress: BudgetProgress(spent: 120_000, budget: 300_000)!, tint: tint, style: .ring)
                BudgetMeter(progress: BudgetProgress(spent: 120_000, budget: 300_000)!, tint: tint, style: .bar)
            }
            .padding()
            .background(Color(tint.surface), in: .rect(cornerRadius: 16))
        }
        BudgetMeter(progress: BudgetProgress(spent: 360_000, budget: 300_000)!, tint: .keinginan, style: .bar)
        BudgetProgress(spent: 360_000, budget: 300_000)!.statusText
    }
    .padding()
    .background(Color(.appBackground))
}
