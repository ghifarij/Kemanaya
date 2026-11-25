import KemanayaCore
import SwiftData
import SwiftUI

/// The **Anggaran** sheet (D-077), opened from the hero's "Anggaran ›" link: every budget in one place.
///
/// An inset-grouped list with a Kebutuhan section and a Keinginan section. Each opens with the group
/// budget row ("Anggaran Kebutuhan"), then the group's visible expense subcategories in the Atur kartu order
/// (pinned first in Home order, then the rest in grid order), each with its emoji and shown name (D-076).
///
/// Every row shows it can be tapped (D-080): a budget shows as its amount and a chevron (change it); no
/// budget shows as a tinted **Atur** on the group row or a `plus.circle` on a subcategory row, in the
/// group's colour (add one). A row with a budget shows one caption, this month's "sisa Rp…" or "lewat Rp…",
/// neutral (D-022). Subcategory budgets are slices of the group budget, not extra money (D-077); the footer
/// says so once. Income has no budget (D-005) and isn't listed.
///
/// Tapping any row opens the one budget keypad, ``BudgetTargetSheet``, on top of this sheet; a card's
/// menu **Atur anggaran** opens the same keypad (D-077). The numbers are live through `@Query`.
struct BudgetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    /// Visible subcategories in grid order; expenses are picked out per group below.
    @Query(
        filter: #Predicate<Subcategory> { !$0.isHidden },
        sort: [SortDescriptor(\Subcategory.sortOrder), SortDescriptor(\Subcategory.name)]
    ) private var visible: [Subcategory]
    /// The settings row, as ``AppSettings/fetchOrCreate(in:)`` picks it; none until the first write.
    @Query(sort: \AppSettings.seedVersion, order: .reverse) private var settings: [AppSettings]
    /// This month's transactions, for "sisa" / "lewat" (fetched by date range only, D-018).
    @Query private var current: [MoneyTransaction]
    /// The group or subcategory whose keypad is open.
    @State private var target: BudgetTarget?

    /// - Parameters:
    ///   - month: the month whose spending "sisa" / "lewat" read (Home's current month).
    ///   - timeZone: the zone `month` is bucketed in.
    init(month: MonthKey, timeZone: TimeZone) {
        _current = Query(MoneyTransaction.descriptor(in: month.dateRange(in: timeZone)))
    }

    var body: some View {
        let summary = MonthSummary(current.map(TransactionSnapshot.init))
        NavigationStack {
            List {
                ForEach(ExpenseGroup.allCases, id: \.self) { group in
                    section(group, summary: summary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.appBackground).ignoresSafeArea())
            .foregroundStyle(Color(.textPrimary))
            .accessibilityIdentifier("budgets.list")
            .navigationTitle(Text(BudgetCopy.budgets))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(BudgetCopy.done)
                    }
                    .accessibilityIdentifier("budgets.done")
                }
            }
            .sheet(item: $target) { target in
                BudgetTargetSheet(target: target)
            }
        }
    }

    // MARK: - Sections

    /// The group row, then the group's subcategories in the Atur kartu order (``PinManagerSheet``).
    private func section(_ group: ExpenseGroup, summary: MonthSummary) -> some View {
        let members = visible.filter { $0.kind == .expense && $0.group == group }
        let pinned = members.filter(\.isPinned).sorted { ($0.pinOrder ?? 0) < ($1.pinOrder ?? 0) }
        let ordered = pinned + members.filter { !$0.isPinned }
        return Section {
            groupRow(group, summary: summary)
            ForEach(ordered) { subcategory in
                subcategoryRow(subcategory, summary: summary)
            }
        } header: {
            Text(group.title)
                // As written, on both OS: iOS 18 would capitalise the header.
                .textCase(nil)
        } footer: {
            if group == ExpenseGroup.allCases.last {
                Text(
                    "Anggaran subkategori termasuk dalam anggaran kelompoknya.",
                    comment: "Anggaran sheet: footer under the last group. A subcategory budget is a slice of its group's budget, not extra money (D-077, D-080)."
                )
            }
        }
    }

    private func groupRow(_ group: ExpenseGroup, summary: MonthSummary) -> some View {
        let budget = settings.first?.budget(for: group)
        let progress = summary.budgetProgress(for: group, budget: budget)
        let name = String(localized: group.title)
        return BudgetsRow(
            emoji: nil,
            title: BudgetCopy.sheetTitle(name),
            budget: budget,
            caption: progress?.compactStatusText(style: style),
            tint: CategoryTint(kind: .expense, group: group),
            isGroup: true
        ) {
            target = .group(group)
        }
        .accessibilityLabel(BudgetCopy.sheetTitle(name))
        .accessibilityValue(progress.map { Text(verbatim: $0.accessibilityStatus) } ?? Text(BudgetCopy.notSet))
        .accessibilityIdentifier("budgets.group.\(group.rawValue)")
    }

    private func subcategoryRow(_ subcategory: Subcategory, summary: MonthSummary) -> some View {
        let progress = summary.budgetProgress(forSubcategory: subcategory.id, budget: subcategory.monthlyBudget)
        return BudgetsRow(
            emoji: subcategory.emoji,
            title: Text(verbatim: subcategory.displayName),
            budget: subcategory.monthlyBudget,
            caption: progress?.compactStatusText(style: style),
            tint: CategoryTint(kind: subcategory.kind, group: subcategory.group),
            isGroup: false
        ) {
            target = .subcategory(subcategory)
        }
        .accessibilityLabel(Text(verbatim: subcategory.displayName))
        .accessibilityValue(progress.map { Text(verbatim: $0.accessibilityStatus) } ?? Text(BudgetCopy.notSet))
        .accessibilityIdentifier("budgets.row.\(subcategory.name)")
    }

    private var style: RupiahFormatter.CompactStyle {
        RupiahFormatter.CompactStyle(locale: locale)
    }
}

/// One row of the Anggaran sheet: the emoji (subcategories), the name, the trailing mark, and at most one
/// caption under the name ("sisa Rp…" / "lewat Rp…"). The trailing mark follows one rule (D-080): a budget
/// shows as its amount and a chevron (change it); no budget shows in the group's colour, **Atur** on the
/// group row and `plus.circle` on a subcategory row (add one). One button and one VoiceOver element; the
/// caller sets its label and value. At accessibility sizes everything stacks, the emoji above the name and
/// the mark under it, so the name and the amount keep the row's width.
private struct BudgetsRow: View {
    let emoji: String?
    let title: Text
    let budget: Int64?
    let caption: Text?
    /// The group's colour family; its ``CategoryTint/bar`` tints the add mark (AA as text on `surface`).
    let tint: CategoryTint
    let isGroup: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        if let emoji {
                            emojiText(emoji)
                        }
                        name
                        mark
                        captionLine
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        if let emoji {
                            emojiText(emoji)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                name
                                Spacer(minLength: 8)
                                mark.layoutPriority(1)
                            }
                            captionLine
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(
            "Ketuk untuk mengatur anggaran.",
            comment: "VoiceOver hint on a row of the Anggaran sheet (a group or an expense subcategory): tapping it opens its monthly budget keypad (D-077)."
        ))
        .listRowBackground(Color(.surface))
    }

    private func emojiText(_ emoji: String) -> some View {
        Text(verbatim: emoji)
            .font(.title3)
    }

    @ViewBuilder private var name: some View {
        if isGroup {
            title
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            // Names are one word (D-007): shrink rather than break mid-word.
            title
                .font(.body)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    /// The amount and a chevron, or the add mark in the group's colour.
    @ViewBuilder private var mark: some View {
        if let budget {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                AmountText(budget, size: .small)
                    .foregroundStyle(Color(.textPrimary))
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
            }
        } else if isGroup {
            Text(Self.set)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(tint.bar))
                .fixedSize()
        } else {
            Image(systemName: "plus.circle")
                .font(.body.weight(.medium))
                .imageScale(.large)
                .foregroundStyle(Color(tint.bar))
        }
    }

    @ViewBuilder private var captionLine: some View {
        if let caption {
            caption
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "Atur": a group row without a budget (D-080). Its own key: the bare "Atur" above Home's cards means
    /// "Manage".
    private static let set = LocalizedStringResource(
        "budgets.set",
        defaultValue: "Atur",
        comment: "Anggaran sheet: the tinted mark on a group row without a budget; tapping the row sets one (D-080). Short verb, English 'Set'."
    )
}

#if DEBUG
/// Preview stores for the Anggaran sheet. Each puts its case in Kebutuhan, the first section, so it shows
/// without scrolling.
private enum BudgetsPreview {
    /// Kebutuhan Rp400rb with Makan Rp300rb and Parkir Rp200rb: the slices add up to more than the group,
    /// and nothing says so (D-041, D-080). Parkir is over its own budget ("lewat").
    static func overAllocated() -> ModelContainer {
        make { context, ledger in
            try ledger.setGroupBudget(400_000, for: .kebutuhan)
            try ledger.setGroupBudget(1_500_000, for: .keinginan)
            try ledger.setMonthlyBudget(300_000, for: subcategory("Makan", context))
            try ledger.setMonthlyBudget(200_000, for: subcategory("Parkir", context))
            try ledger.setMonthlyBudget(250_000, for: subcategory("Jajan", context))
            try ledger.addTransaction(amount: 250_000, subcategory: subcategory("Parkir", context), date: .now, note: nil)
        }
    }

    /// Kebutuhan Rp5jt with Makan Rp500rb inside it.
    static func within() -> ModelContainer {
        make { context, ledger in
            try ledger.setGroupBudget(5_000_000, for: .kebutuhan)
            try ledger.setMonthlyBudget(500_000, for: subcategory("Makan", context))
        }
    }

    /// No group budgets, Makan Rp500rb: the group rows show Atur.
    static func slicesOnly() -> ModelContainer {
        make { context, ledger in
            try ledger.setMonthlyBudget(500_000, for: subcategory("Makan", context))
        }
    }

    private static func make(_ setUp: (ModelContext, Ledger) throws -> Void) -> ModelContainer {
        let container = PreviewStore.makeContainer()
        do {
            let context = container.mainContext
            try setUp(context, Ledger(context: context, timeZone: .autoupdatingCurrent))
        } catch {
            fatalError("Budgets preview failed: \(error)")
        }
        return container
    }

    private static func subcategory(_ name: String, _ context: ModelContext) throws -> Subcategory {
        guard let found = try context.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == name })).first else {
            fatalError("No \(name) in the seed")
        }
        return found
    }

    static func sheet(_ container: ModelContainer) -> some View {
        let month = CurrentMonth.now
        return BudgetsSheet(month: month.month, timeZone: month.timeZone)
            .modelContainer(container)
    }
}

#Preview("Over-allocated") {
    BudgetsPreview.sheet(BudgetsPreview.overAllocated())
}

#Preview("Within") {
    BudgetsPreview.sheet(BudgetsPreview.within())
}

#Preview("Slices only") {
    BudgetsPreview.sheet(BudgetsPreview.slicesOnly())
}

#Preview("Empty") {
    BudgetsPreview.sheet(PreviewStore.makeContainer(withSamples: false))
}
#endif
