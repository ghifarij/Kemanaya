import KemanayaCore
import SwiftUI

/// How much of a budget is used (D-010, D-041), as a bar (the subcategory detail) or a thin bar (a Home
/// card, D-068). Analisis' ranked rows show no meter, only a labelled line (D-081).
///
/// Neutral on purpose (D-022, D-041): going over fills the meter in the same group color, with no red
/// and no alarm; the caption says "lewat" plainly. Purely visual: the caller's text carries the numbers
/// for VoiceOver.
struct BudgetMeter: View {
    enum Style {
        /// A full-width bar.
        case bar
        /// A thinner bar, for a compact card's third line (D-068).
        case thinBar
    }

    let progress: BudgetProgress
    let tint: CategoryTint
    let style: Style

    var body: some View {
        Group {
            switch style {
            case .bar: MeterBar(fraction: progress.clampedFraction, tint: tint)
            case .thinBar: MeterBar(fraction: progress.clampedFraction, tint: tint, thickness: .thin)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A horizontal meter: a quiet track filled to `fraction` in the group's Strong colour (D-040).
/// Budget bars use it. Purely visual; callers carry the numbers.
struct MeterBar: View {
    enum Thickness {
        case regular, thin
    }

    let fraction: Double
    let tint: CategoryTint
    var thickness: Thickness = .regular

    @ScaledMetric(relativeTo: .caption) private var regularHeight: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var thinHeight: CGFloat = 6

    var body: some View {
        let height = thickness == .regular ? regularHeight : thinHeight
        let clamped = min(max(fraction, 0), 1)
        Capsule()
            .fill(Color(tint.content).opacity(0.1))
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color(tint.bar))
                        // Anything above zero shows at least a dot.
                        .frame(width: clamped > 0 ? max(proxy.size.width * clamped, height) : 0)
                }
            }
            .accessibilityHidden(true)
    }
}

extension BudgetProgress {
    /// An Analisis ranked row's third line (D-081) and the subcategory detail's budget card (D-082):
    /// "Anggaran: sisa Rp250.000", or "Anggaran: lewat Rp36.500" once over, in the full amount format.
    /// Neutral (D-022, D-041): it names the number and states it, never praised or blamed.
    var labelledStatusText: Text {
        if isOverBudget {
            Text(
                "Anggaran: lewat \((-remaining).rupiahFormatted)",
                comment: "Analisis ranked row and the subcategory detail's budget card: the subcategory's budget when spending went over it, e.g. 'Anggaran: lewat Rp36.500' (D-081, D-082). Neutral: state it, never blame. The placeholder is the amount over."
            )
        } else {
            Text(
                "Anggaran: sisa \(remaining.rupiahFormatted)",
                comment: "Analisis ranked row and the subcategory detail's budget card: what is left of the subcategory's budget this month, e.g. 'Anggaran: sisa Rp250.000' (D-081, D-082). The placeholder is the amount left."
            )
        }
    }

    /// A compact card's caption (D-068): "sisa Rp80rb", or "lewat Rp10rb" once over, in the short
    /// amount format. Neutral, like ``labelledStatusText`` (D-022). The Home hero's legend uses it too (D-073).
    func compactStatusText(style: RupiahFormatter.CompactStyle) -> Text {
        if isOverBudget {
            Text(
                "lewat \((-remaining).rupiahShort(style))",
                comment: "Budget caption on a Home card, or under a group's amount in the Home hero, when spending went over the budget, e.g. 'lewat Rp10rb' (D-068, D-073). Lower case, neutral: state it, never blame. The placeholder is the short amount over."
            )
        } else {
            Text(
                "sisa \(remaining.rupiahShort(style))",
                comment: "Budget caption on a Home card, or under a group's amount in the Home hero: what is left of the budget this month, e.g. 'sisa Rp80rb' (D-068, D-073). Lower case. The placeholder is the short amount left."
            )
        }
    }

    /// VoiceOver's reading of a budget's status, with the budget, in whole rupiah.
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
                BudgetMeter(progress: BudgetProgress(spent: 120_000, budget: 300_000)!, tint: tint, style: .bar)
                BudgetMeter(progress: BudgetProgress(spent: 120_000, budget: 300_000)!, tint: tint, style: .thinBar)
            }
            .padding()
            .background(Color(tint.surface), in: .rect(cornerRadius: 16))
        }
        BudgetMeter(progress: BudgetProgress(spent: 360_000, budget: 300_000)!, tint: .keinginan, style: .bar)
        BudgetProgress(spent: 360_000, budget: 300_000)!.labelledStatusText
    }
    .padding()
    .background(Color(.appBackground))
}
