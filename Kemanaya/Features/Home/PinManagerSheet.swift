import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// Atur kartu (D-048, D-068): every visible subcategory with a pin toggle, in three sections, Kebutuhan,
/// Keinginan and Pemasukan, the Home sections. In each, the pinned ones sit on top in Home order and drag
/// to reorder within the section; the unpinned follow in grid order. Each header counts the section's pins
/// against its limit ("3 dari 6 dipin") and each footer states the limit. Every change saves at once through
/// ``Ledger``, so Home updates behind the sheet.
///
/// A pin past a section's limit is refused (D-068): the toggle stays off, a warning haptic plays and a
/// short note appears at the bottom; VoiceOver hears the same note.
///
/// Budgets are set here too (D-069): the Kebutuhan and Keinginan headers carry the group budget
/// ("Anggaran Rp4jt ›", or "Atur anggaran ›"), and each expense row shows its budget or "—"; tapping
/// either opens ``BudgetTargetSheet`` on top of this sheet. Income has no budget (D-005).
struct PinManagerSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Visible subcategories in grid order; pinned ones are picked out below.
    @Query(
        filter: #Predicate<Subcategory> { !$0.isHidden },
        sort: [SortDescriptor(\Subcategory.sortOrder), SortDescriptor(\Subcategory.name)]
    ) private var visible: [Subcategory]

    /// Bumped on each refused pin: shows the note and plays the haptic.
    @State private var refusedCount = 0
    /// The section whose limit the last refused pin hit.
    @State private var refusedSection = PinSection.kebutuhan
    @State private var showsLimitNote = false
    @State private var showsSaveError = false
    /// The group or subcategory whose budget sheet is open (D-069).
    @State private var budgetTarget: BudgetTarget?
    /// The settings row, as ``AppSettings/fetchOrCreate(in:)`` picks it; none until the first write.
    @Query(sort: \AppSettings.seedVersion, order: .reverse) private var settings: [AppSettings]
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            List {
                ForEach(PinSection.allCases, id: \.self) { section in
                    pinSection(section)
                }
            }
            // Always in edit mode, so pinned rows show their reorder handles; toggles still work.
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color(.appBackground).ignoresSafeArea())
            .foregroundStyle(Color(.textPrimary))
            .accessibilityIdentifier("pins.list")
            .navigationTitle(Text("Atur kartu", comment: "Title of the pin management sheet, and VoiceOver label of the Atur button that opens it."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Selesai", comment: "Closes the pin management sheet. Changes are already saved.")
                    }
                    .accessibilityIdentifier("pins.done")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showsLimitNote {
                    limitNote
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $budgetTarget) { target in
                BudgetTargetSheet(target: target)
            }
        }
        .sensoryFeedback(.warning, trigger: refusedCount)
        .task(id: refusedCount) {
            guard refusedCount > 0 else { return }
            withAnimation { showsLimitNote = true }
            AccessibilityNotification.Announcement(limitMessage).post()
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { showsLimitNote = false }
        }
        .alert(
            Text("Perubahan kartu belum tersimpan", comment: "Alert title in pin management when saving a pin, unpin or reorder failed and trying again may work."),
            isPresented: $showsSaveError
        ) {
            Button {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: {
            Text("Coba ubah sekali lagi ya.", comment: "Alert message when saving a change failed (a pin, the order of cards or subcategories, or Tampilkan): asks to try again.")
        }
    }

    // MARK: - Sections

    /// One Home section (D-068): its pinned subcategories in Home order (reorderable), then the rest in
    /// grid order.
    private func pinSection(_ section: PinSection) -> some View {
        let members = visible.filter { $0.pinSection == section }
        let pinned = members.filter(\.isPinned).sorted { ($0.pinOrder ?? 0) < ($1.pinOrder ?? 0) }
        let unpinned = members.filter { !$0.isPinned }
        return Section {
            // Identified apart from the same subcategory's unpinned row: a row that kept its identity
            // while moving into the pinned rows came without its reorder handle until reopened.
            ForEach(Array(pinned.enumerated()), id: \.element.pinnedRowID) { index, subcategory in
                row(for: subcategory)
                    .accessibilityActions {
                        if index > 0 {
                            Button {
                                move(in: section, from: index, to: index - 1)
                            } label: {
                                Text("Geser ke atas", comment: "VoiceOver action on a reorderable row (a pinned card in Atur kartu, or a subcategory in Kelola subkategori): moves it one place earlier.")
                            }
                        }
                        if index < pinned.count - 1 {
                            Button {
                                move(in: section, from: index, to: index + 2)
                            } label: {
                                Text("Geser ke bawah", comment: "VoiceOver action on a reorderable row (a pinned card in Atur kartu, or a subcategory in Kelola subkategori): moves it one place later.")
                            }
                        }
                    }
            }
            .onMove { source, destination in
                movePins(in: section, source, destination)
            }
            ForEach(unpinned) { subcategory in
                row(for: subcategory)
            }
        } header: {
            header(for: section, pinnedCount: pinned.count)
        } footer: {
            Text(
                "Maksimal \(section.limit) di Beranda. Seret untuk mengubah urutan.",
                comment: "Pin management: a section footer. The placeholder is the section's pin limit (6 for Kebutuhan and Keinginan, 3 for Pemasukan, D-068); pinned rows drag to reorder."
            )
        }
    }

    // MARK: - Header

    /// "Kebutuhan  3 dari 6 dipin ……… Anggaran Rp4jt ›": the section and its pin count, then its group budget
    /// control trailing (D-069; Pemasukan has none). On one line while it fits; otherwise the control
    /// goes under the name, and at accessibility sizes the count does too, so no word breaks.
    private func header(for section: PinSection, pinnedCount: Int) -> some View {
        let nameAndCount = (dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))) {
            Text(section.title)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(
                "\(pinnedCount) dari \(section.limit) dipin",
                comment: "Pin management: a section header's count, e.g. '3 dari 6 dipin' ('3 of 6 pinned'): cards pinned now out of the section's limit (D-068, D-073)."
            )
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pins.header.\(section.rawValue)")
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                nameAndCount.fixedSize()
                Spacer(minLength: 8)
                if let group = section.group {
                    groupBudgetButton(group).fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                nameAndCount
                if let group = section.group {
                    groupBudgetButton(group)
                }
            }
        }
        // As written, on both OS: iOS 18 would capitalise the header, VoiceOver's reading included.
        .textCase(nil)
    }

    /// "Anggaran Rp4jt ›" or "Atur anggaran ›": opens the group's budget sheet (D-069).
    private func groupBudgetButton(_ group: ExpenseGroup) -> some View {
        let budget = settings.first?.budget(for: group)
        return Button {
            budgetTarget = .group(group)
        } label: {
            HStack(spacing: 2) {
                if let budget {
                    Text(LocalizedStringResource(
                        "pins.groupBudget",
                        defaultValue: "Anggaran \(budget.rupiahShort(RupiahFormatter.CompactStyle(locale: locale)))",
                        comment: "Atur kartu: a Kebutuhan or Keinginan section header's link showing the group's monthly budget in the short format, e.g. 'Anggaran Rp4jt'; tapping it opens the budget keypad (D-069)."
                    ))
                    .monospacedDigit()
                } else {
                    Text(BudgetCopy.setBudget)
                }
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(.brand))
            // An amount shrinks rather than cuts digits (D-040).
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(LocalizedStringResource(
            "pins.groupBudget.accessibilityLabel",
            defaultValue: "Anggaran \(String(localized: group.title))",
            comment: "VoiceOver label of the budget link in an Atur kartu section header, e.g. 'Anggaran Kebutuhan' (D-069). Its value is the budget in rupiah or 'Belum diatur'."
        )))
        .accessibilityValue(budgetReading(budget))
        .accessibilityIdentifier("pins.groupBudget.\(group.rawValue)")
    }

    // MARK: - Rows

    /// The emoji and name, then the budget ("Anggaran Rp300rb" or "—") for an expense (D-069), then the pin toggle.
    /// Tapping an expense row outside the toggle opens its budget sheet; income rows only pin.
    private func row(for subcategory: Subcategory) -> some View {
        HStack(spacing: 12) {
            if subcategory.kind == .expense {
                // Borderless, so the row's button works in the list's edit mode and only its own area
                // reacts: the toggle and the reorder handle keep their touches.
                Button {
                    budgetTarget = .subcategory(subcategory)
                } label: {
                    // At accessibility sizes the budget goes under the name, so the name keeps the width.
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(spacing: 12))
                    layout {
                        rowName(subcategory)
                        if !dynamicTypeSize.isAccessibilitySize {
                            Spacer(minLength: 8)
                        }
                        rowBudget(subcategory.monthlyBudget)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color(.textPrimary))
                .accessibilityLabel(Text(verbatim: subcategory.displayName))
                .accessibilityValue(budgetReading(subcategory.monthlyBudget))
                .accessibilityHint(Text(
                    "Ketuk untuk mengatur anggaran.",
                    comment: "VoiceOver hint on an expense subcategory row in Atur kartu: tapping it opens its monthly budget keypad (D-069)."
                ))
                .accessibilityIdentifier("pins.budget.\(subcategory.name)")
            } else {
                rowName(subcategory)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityHidden(true)
            }
            Toggle(isOn: pinBinding(for: subcategory)) {
                Text(verbatim: subcategory.displayName)
            }
            .labelsHidden()
            .fixedSize()
            .tint(Color(.brand))
            .accessibilityIdentifier("pins.toggle.\(subcategory.name)")
        }
        .listRowBackground(Color(.surface))
    }

    /// The emoji and name. At accessibility sizes the emoji goes above the name, so the name keeps the
    /// row's width; a name shrinks rather than breaking mid-word (names are one word, D-007).
    private func rowName(_ subcategory: Subcategory) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(verbatim: subcategory.emoji)
                .font(.title3)
                .accessibilityHidden(true)
            Text(verbatim: subcategory.displayName)
                .font(.body)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    /// "Anggaran Rp300rb" (D-073: the amount says what it is), or "—" when no budget is set. An amount
    /// shrinks rather than cuts digits (D-040).
    private func rowBudget(_ budget: Int64?) -> some View {
        Group {
            if let budget {
                Text(LocalizedStringResource(
                    "pins.rowBudget",
                    defaultValue: "Anggaran \(budget.rupiahShort(RupiahFormatter.CompactStyle(locale: locale)))",
                    comment: "Atur kartu: an expense subcategory row's monthly budget in the short format, e.g. 'Anggaran Rp300rb'; tapping the row opens the budget keypad (D-069, D-073)."
                ))
            } else {
                Text(verbatim: "—")
            }
        }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Color(.textSecondary))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .layoutPriority(1)
    }

    /// VoiceOver's reading of a budget: whole rupiah, or "Belum diatur".
    private func budgetReading(_ budget: Int64?) -> Text {
        guard let budget else { return Text(BudgetCopy.notSet) }
        return Text("\(budget) rupiah", comment: "VoiceOver reading of a money amount. The number is whole rupiah, without separators.")
    }

    /// The note shown after a refused pin, on glass above the list's bottom edge.
    private var limitNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "pin.slash")
                .accessibilityHidden(true)
            Text(limitMessage)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color(.textPrimary))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .kemanayaGlass(in: .rect(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pins.limitNote")
    }

    private var limitMessage: String {
        String(
            localized: "Maksimal \(refusedSection.limit) \(String(localized: refusedSection.title)) di Beranda. Lepas satu dulu untuk menambah yang lain.",
            comment: "Pin management: note shown when a pin past a section's limit is refused (D-068). 1: the limit (6 or 3), 2: the section, Kebutuhan, Keinginan or Pemasukan."
        )
    }

    // MARK: - Writes

    private var ledger: Ledger {
        Ledger(context: context, timeZone: .autoupdatingCurrent)
    }

    private func pinBinding(for subcategory: Subcategory) -> Binding<Bool> {
        Binding {
            subcategory.isPinned
        } set: { isOn in
            do {
                try withAnimation {
                    if isOn {
                        try ledger.pin(subcategory)
                    } else {
                        try ledger.unpin(subcategory)
                    }
                }
            } catch PinError.limitReached(let section) {
                refusedSection = section
                refusedCount += 1
            } catch {
                HomeLog.logger.error("Changing a pin failed: \(error.localizedDescription, privacy: .public)")
                showsSaveError = true
            }
        }
    }

    private func move(in section: PinSection, from index: Int, to destination: Int) {
        movePins(in: section, IndexSet(integer: index), destination)
    }

    private func movePins(in section: PinSection, _ source: IndexSet, _ destination: Int) {
        do {
            try ledger.movePins(in: section, fromOffsets: source, toOffset: destination)
        } catch {
            HomeLog.logger.error("Reordering pins failed: \(error.localizedDescription, privacy: .public)")
            showsSaveError = true
        }
    }
}

private extension Subcategory {
    /// The pinned section's row identity (see ``PinManagerSheet``).
    var pinnedRowID: String { "pinned-\(id.uuidString)" }
}

#if DEBUG
#Preview {
    PinManagerSheet()
        .modelContainer(PreviewStore.makeContainer())
}
#endif
