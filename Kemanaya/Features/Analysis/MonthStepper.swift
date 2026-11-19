import KemanayaCore
import SwiftUI

/// "‹ November 2026 ›": picks the month the whole Analisis page shows (D-051), from the current month
/// back through the 13-month window (D-017). An end of the range disables its arrow.
///
/// VoiceOver reads it as one adjustable element ("Bulan, November 2026"): swipe up for the next month,
/// down for the previous one, like a picker wheel.
struct MonthStepper: View {
    @Binding var month: MonthKey
    let range: AnalysisMonthRange
    let timeZone: TimeZone

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Grows with the text but is capped, so the month keeps the width at accessibility sizes.
    @ScaledMetric(relativeTo: .headline) private var scaledArrowSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 4) {
            arrow(systemImage: "chevron.left", target: range.month(before: month))
            monthLabel
                .font(.headline)
                .frame(maxWidth: .infinity)
            arrow(systemImage: "chevron.right", target: range.month(after: month))
        }
        .padding(4)
        .background(Color(.surface), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Bulan", comment: "VoiceOver label of the Analisis month stepper; its value is the month shown, e.g. November 2026."))
        .accessibilityValue(Text(verbatim: title))
        .accessibilityHint(Text(
            "Geser ke atas atau ke bawah untuk mengganti bulan.",
            comment: "VoiceOver hint of the Analisis month stepper: swipe up or down to change the month."
        ))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(to: range.month(after: month))
            case .decrement: step(to: range.month(before: month))
            @unknown default: break
            }
        }
        .accessibilityIdentifier("analysis.month")
    }

    /// "November 2026", Gregorian and formatted in the zone the month is bucketed in.
    private var title: String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }

    /// One line; at accessibility sizes the month and the year each get a line. Never split mid-word:
    /// a line shrinks instead.
    @ViewBuilder private var monthLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            let start = month.start(in: timeZone)
            VStack(spacing: 0) {
                Text(verbatim: start.formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(verbatim: start.formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).year()))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        } else {
            Text(verbatim: title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var arrowSize: CGFloat { min(scaledArrowSize, 60) }

    private func arrow(systemImage: String, target: MonthKey?) -> some View {
        Button {
            step(to: target)
        } label: {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: arrowSize, height: arrowSize)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(target == nil ? .textSecondary : .brand))
        .disabled(target == nil)
        .opacity(target == nil ? 0.4 : 1)
    }

    private func step(to target: MonthKey?) {
        guard let target else { return }
        month = target
    }
}
