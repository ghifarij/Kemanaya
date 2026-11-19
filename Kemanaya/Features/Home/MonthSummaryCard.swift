import KemanayaCore
import SwiftUI

/// Home's month block (D-009, D-010, D-014, D-041): spending this month, sisa and savings rate, the
/// Kebutuhan / Keinginan split, and group budgets only when one is set (D-048). A month with nothing
/// logged shows a calm note instead of a row of zeros.
///
/// Numbers only, no verdicts (D-022): no praise for spending, no alarm for going over.
struct MonthSummaryCard: View {
    let overview: HomeOverview

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if overview.isEmpty {
                emptyState
            } else {
                totals
                SplitBar(kebutuhan: overview.month.kebutuhan, keinginan: overview.month.keinginan)
            }
            if !overview.groupBudgets.isEmpty {
                budgets
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.surface), in: .rect(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Totals

    private var totals: some View {
        let month = overview.month
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                caption(Text("Pengeluaran bulan ini", comment: "Home: label above this month's total spending."))
                AmountText(month.expenses, size: .large)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home.expenses")

            layout {
                VStack(alignment: .leading, spacing: 2) {
                    caption(Text("Sisa bulan ini", comment: "Home: label above income minus spending this month (D-009). Can be negative."))
                    AmountText(month.sisa, size: .medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.sisa")

                VStack(alignment: .leading, spacing: 2) {
                    caption(Self.savingsRateLabel)
                    savingsRate(month)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.savingsRateLabel)
                .accessibilityValue(savingsRateAccessibilityValue(month))
                .accessibilityIdentifier("home.savingsRate")
            }
        }
    }

    private static var savingsRateLabel: Text {
        Text("Rasio tabungan", comment: "Home: label above the savings rate, sisa as a share of income (D-009).")
    }

    /// The rate in the amount type, or a plain note when there is no income yet (the rate is undefined).
    /// A negative rate gets a neutral note under it, in the secondary colour, never an alarm (D-050).
    @ViewBuilder private func savingsRate(_ month: MonthSummary) -> some View {
        if let percent = month.savingsRatePercent {
            Text(percent, format: .percent)
                .font(.amountMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if month.isSavingsRateNegative {
                Text(Self.overspentNote)
                    .font(.footnote)
                    .foregroundStyle(Color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.savingsRate.overspent")
            }
        } else {
            Text(Self.noIncomeNote)
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The rate, plus the overspent note when it is negative; or the no-income note.
    private func savingsRateAccessibilityValue(_ month: MonthSummary) -> Text {
        guard let percent = month.savingsRatePercent else { return Text(Self.noIncomeNote) }
        let rate = percent.formatted(.percent.locale(locale))
        guard month.isSavingsRateNegative else { return Text(verbatim: rate) }
        return Text(String(
            localized: "home.savingsRate.accessibilityValue.overspent",
            defaultValue: "\(rate), \(String(localized: Self.overspentNote))",
            comment: "VoiceOver value of Home's savings rate when spending exceeds income (D-050). 1: the rate, e.g. -15%, 2: the note 'Pengeluaran melebihi pemasukan'. Keep the order."
        ))
    }

    private static let overspentNote = LocalizedStringResource(
        "Pengeluaran melebihi pemasukan",
        comment: "Home: neutral note under a negative savings rate, when this month's spending is more than its income (D-050). State the fact only, no alarm or judgment."
    )

    private static let noIncomeNote = LocalizedStringResource(
        "Belum ada pemasukan",
        comment: "Home: shown instead of the savings rate while no income is logged this month."
    )

    // MARK: - Budgets

    private var budgets: some View {
        VStack(alignment: .leading, spacing: 14) {
            caption(Text("Anggaran bulan ini", comment: "Home: header above the Kebutuhan / Keinginan budget bars."))
                .accessibilityAddTraits(.isHeader)
            ForEach(overview.groupBudgets) { item in
                GroupBudgetRow(group: item.group, progress: item.progress)
            }
        }
    }

    // MARK: - Empty

    /// Nothing logged this month: a calm pointer to the cards and "+", never a verdict (D-022).
    private var emptyState: some View {
        // The icon sits beside the text, or above it at accessibility sizes so the text keeps the width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            Image(systemName: "tray")
                .font(.title3)
                .foregroundStyle(Color(.textSecondary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Bulan ini masih kosong", comment: "Home empty state title: nothing logged this month yet.")
                    .font(.headline)
                Text(
                    "Ketuk kartu di bawah atau + untuk mencatat pengeluaran atau pemasukan.",
                    comment: "Home empty state description: tap a card below or + to log an expense or income."
                )
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.empty")
    }

    private func caption(_ text: Text) -> some View {
        text
            .font(.subheadline)
            .foregroundStyle(Color(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One group budget: name, "spent of budget", a bar and what is left or over (D-010, D-041).
private struct GroupBudgetRow: View {
    let group: ExpenseGroup
    let progress: BudgetProgress

    var body: some View {
        let tint = CategoryTint(kind: .expense, group: group)
        VStack(alignment: .leading, spacing: 6) {
            // One row when everything fits at full size; otherwise the title, the spent amount and
            // "dari <budget>" each get a line, so no amount is cut or shrunk to unreadable.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    title
                    Spacer(minLength: 0)
                    spentOfBudget
                }
                VStack(alignment: .leading, spacing: 2) {
                    title
                    amountLine(Text(verbatim: progress.spent.rupiahFormatted))
                    amountLine(Text(
                        "dari \(progress.budget.rupiahFormatted)",
                        comment: "Group budget on Home, on its own line at large text sizes: out of the budget, e.g. 'dari Rp3.000.000'."
                    ))
                }
            }
            BudgetMeter(progress: progress, tint: tint, style: .bar)
            progress.statusText
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color(.textSecondary))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "Anggaran \(Text(group.title))",
            comment: "VoiceOver label of a group budget on Home. The placeholder is the group name, Kebutuhan or Keinginan."
        ))
        .accessibilityValue(Text(String(
            localized: "terpakai \(progress.spent) rupiah, \(progress.accessibilityStatus)",
            comment: "VoiceOver value of a group budget on Home. 1: spent this month in whole rupiah, 2: the budget and what is left or over."
        )))
        .accessibilityIdentifier("home.budget.\(group.rawValue)")
    }

    private var title: some View {
        Text(group.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    /// "Rp1.344.000 dari Rp3.000.000" at its full size, so `ViewThatFits` only picks the one-row layout
    /// when it really fits.
    private var spentOfBudget: some View {
        Text(
            "\(progress.spent.rupiahFormatted) dari \(progress.budget.rupiahFormatted)",
            comment: "Group budget on Home: spent this month out of the budget, e.g. 'Rp1.344.000 dari Rp3.000.000'."
        )
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(Color(.textSecondary))
        .lineLimit(1)
        .fixedSize()
    }

    /// One amount line of the stacked layout: shrinks rather than wraps or cuts digits (D-040).
    private func amountLine(_ text: Text) -> some View {
        text
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Color(.textSecondary))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

#Preview {
    let id = UUID()
    let current = [
        TransactionSnapshot(amount: 1_344_000, kind: .expense, group: .kebutuhan, subcategoryID: id, date: .now),
        TransactionSnapshot(amount: 431_500, kind: .expense, group: .keinginan, subcategoryID: UUID(), date: .now),
        TransactionSnapshot(amount: 8_500_000, kind: .income, group: nil, subcategoryID: UUID(), date: .now),
    ]
    ScrollView {
        VStack(spacing: 16) {
            MonthSummaryCard(overview: HomeOverview(current: current, previous: [], pins: [], groupBudgets: [.kebutuhan: 3_000_000, .keinginan: 400_000]))
            MonthSummaryCard(overview: HomeOverview(current: current + [
                TransactionSnapshot(amount: 7_000_000, kind: .expense, group: .keinginan, subcategoryID: UUID(), date: .now),
            ], previous: [], pins: [], groupBudgets: [:]))
            MonthSummaryCard(overview: HomeOverview(current: [], previous: [], pins: [], groupBudgets: [:]))
        }
        .padding()
    }
    .foregroundStyle(Color(.textPrimary))
    .background(Color(.appBackground))
}
