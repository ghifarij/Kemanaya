import KemanayaCore
import SwiftData
import SwiftUI

/// The **Anggaran** sheet (D-077), opened from the hero's "Anggaran ›" link: every budget in one place.
///
/// An inset-grouped list with a Kebutuhan section and a Keinginan section. Each opens with the group
/// budget row ("Anggaran Kebutuhan", its amount or "Belum diatur"), then the group's visible expense
/// subcategories in the Atur kartu order (pinned first in Home order, then the rest in grid order), each
/// with its emoji, shown name (D-076) and budget or "—". A row with a budget shows this month's "sisa Rp…"
/// or "lewat Rp…" under it, neutral (D-022). Income has no budget (D-005) and isn't listed.
///
/// Subcategory budgets are slices of the group budget, not extra money (D-077): under the group row,
/// ``BudgetAllocation`` says how much is given to subcategories and how much is free, or, neutrally,
/// that the slices add up to more than the group budget. Nothing is blocked or auto-filled (D-041).
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
        let groupBudget = settings.first?.budget(for: group)
        let allocation = BudgetAllocation(groupBudget: groupBudget, subcategoryBudgets: members.map(\.monthlyBudget))
        return Section {
            groupRow(group, budget: groupBudget, allocation: allocation, summary: summary)
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
                    "Anggaran subkategori adalah bagian dari anggaran kelompoknya, bukan tambahan.",
                    comment: "Anggaran sheet: footer under the last group. A subcategory budget is a slice of its group's budget, not extra money (D-077)."
                )
            }
        }
    }

    private func groupRow(_ group: ExpenseGroup, budget: Int64?, allocation: BudgetAllocation, summary: MonthSummary) -> some View {
        let progress = summary.budgetProgress(for: group, budget: budget)
        let name = String(localized: group.title)
        var captions: [Text] = []
        var readings: [String] = []
        if let progress {
            captions.append(progress.compactStatusText(style: style))
            readings.append(progress.accessibilityStatus)
        } else {
            readings.append(String(localized: BudgetCopy.notSet))
        }
        if let line = allocationLine(allocation.summary, groupName: name) {
            captions.append(line.text)
            readings.append(line.reading)
        }
        return BudgetsRow(
            emoji: nil,
            title: BudgetCopy.sheetTitle(name),
            budget: budget,
            emptyValue: Text(BudgetCopy.notSet),
            captions: captions,
            isGroup: true
        ) {
            target = .group(group)
        }
        .accessibilityLabel(BudgetCopy.sheetTitle(name))
        .accessibilityValue(Text(verbatim: readings.joined(separator: ", ")))
        .accessibilityIdentifier("budgets.group.\(group.rawValue)")
    }

    private func subcategoryRow(_ subcategory: Subcategory, summary: MonthSummary) -> some View {
        let progress = summary.budgetProgress(forSubcategory: subcategory.id, budget: subcategory.monthlyBudget)
        return BudgetsRow(
            emoji: subcategory.emoji,
            title: Text(verbatim: subcategory.displayName),
            budget: subcategory.monthlyBudget,
            emptyValue: Text(verbatim: "—"),
            captions: progress.map { [$0.compactStatusText(style: style)] } ?? [],
            isGroup: false
        ) {
            target = .subcategory(subcategory)
        }
        .accessibilityLabel(Text(verbatim: subcategory.displayName))
        .accessibilityValue(progress.map { Text(verbatim: $0.accessibilityStatus) } ?? Text(BudgetCopy.notSet))
        .accessibilityIdentifier("budgets.row.\(subcategory.name)")
    }

    // MARK: - Allocation (D-077)

    private var style: RupiahFormatter.CompactStyle {
        RupiahFormatter.CompactStyle(locale: locale)
    }

    /// The line under a group row, in the short amount format, and its VoiceOver reading in whole rupiah.
    private func allocationLine(_ summary: BudgetAllocation.Summary, groupName: String) -> (text: Text, reading: String)? {
        switch summary {
        case .none:
            return nil
        case .slicesOnly(let allocated):
            return (
                Text(LocalizedStringResource(
                    "budgets.allocation.slicesOnly",
                    defaultValue: "\(allocated.rupiahShort(style)) untuk subkategori",
                    comment: "Anggaran sheet: under a group row without a group budget whose subcategories have budgets, e.g. 'Rp500rb untuk subkategori' (D-077). The placeholder is their sum in the short format."
                )),
                String(
                    localized: "budgets.allocation.slicesOnly.accessibility",
                    defaultValue: "\(allocated) rupiah untuk subkategori",
                    comment: "VoiceOver: the sum of a group's subcategory budgets when the group has no budget (D-077), in whole rupiah."
                )
            )
        case .within(let allocated, let free):
            return (
                Text(LocalizedStringResource(
                    "budgets.allocation.within",
                    defaultValue: "\(allocated.rupiahShort(style)) untuk subkategori · \(free.rupiahShort(style)) bebas",
                    comment: "Anggaran sheet: under a group row, how the group budget is shared, e.g. 'Rp500rb untuk subkategori · Rp4,5jt bebas' (D-077). 1: the sum of its subcategory budgets, 2: the part of the group budget not given to a subcategory, both in the short format."
                )),
                String(
                    localized: "budgets.allocation.within.accessibility",
                    defaultValue: "\(allocated) rupiah untuk subkategori, \(free) rupiah bebas",
                    comment: "VoiceOver: how a group budget is shared (D-077), in whole rupiah. 1: the sum of its subcategory budgets, 2: the part not given to a subcategory."
                )
            )
        case .over(let allocated, _):
            return (
                Text(LocalizedStringResource(
                    "budgets.allocation.over",
                    defaultValue: "Subkategori \(allocated.rupiahShort(style)), lebih dari anggaran \(groupName)",
                    comment: "Anggaran sheet: under a group row when its subcategory budgets add up to more than the group budget, e.g. 'Subkategori Rp5,5jt, lebih dari anggaran Kebutuhan' (D-077). Neutral: nothing is wrong or blocked. 1: their sum in the short format, 2: the group, Kebutuhan or Keinginan."
                )),
                String(
                    localized: "budgets.allocation.over.accessibility",
                    defaultValue: "subkategori \(allocated) rupiah, lebih dari anggaran \(groupName)",
                    comment: "VoiceOver: a group's subcategory budgets add up to more than its budget (D-077). Neutral. 1: their sum in whole rupiah, 2: the group, Kebutuhan or Keinginan."
                )
            )
        }
    }
}

/// One row of the Anggaran sheet: the emoji (subcategories), the name, the budget or `emptyValue`
/// trailing, and caption lines under the name ("sisa Rp…", the allocation line). One button and one
/// VoiceOver element; the caller sets its label and value. At accessibility sizes everything stacks, the
/// emoji above the name and the amount under it, so the name and the amount keep the row's width.
private struct BudgetsRow: View {
    let emoji: String?
    let title: Text
    let budget: Int64?
    let emptyValue: Text
    let captions: [Text]
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
                        value
                        captionLines
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
                                value.layoutPriority(1)
                            }
                            captionLines
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

    @ViewBuilder private var value: some View {
        if let budget {
            AmountText(budget, size: .small)
                .foregroundStyle(Color(.textPrimary))
        } else {
            emptyValue
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var captionLines: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(captions.enumerated()), id: \.offset) { _, caption in
                caption
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
/// Preview stores for the Anggaran sheet. Each puts its case in Kebutuhan, the first section, so it shows
/// without scrolling.
private enum BudgetsPreview {
    /// Kebutuhan Rp400rb with Makan Rp300rb and Parkir Rp200rb: the slices add up to more than the group.
    /// Parkir is over its own budget too ("lewat").
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

    /// Kebutuhan Rp5jt with Makan Rp500rb inside it: "Rp500rb untuk subkategori · Rp4,5jt bebas".
    static func within() -> ModelContainer {
        make { context, ledger in
            try ledger.setGroupBudget(5_000_000, for: .kebutuhan)
            try ledger.setMonthlyBudget(500_000, for: subcategory("Makan", context))
        }
    }

    /// No group budgets, Makan Rp500rb: "Rp500rb untuk subkategori".
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
