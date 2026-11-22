import KemanayaCore
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The Beranda tab, the app's root (D-048, D-068): the hero (the month's spending and a row per group),
/// then the pinned cards in a Kebutuhan column and a Keinginan column, then pinned income as thin rows.
/// The hero pushes this month's transactions. "+" in the toolbar opens the add sheet; a card or income
/// row opens it with its subcategory preselected; **Atur** opens pin management.
/// A card's long-press menu is **Lihat detail · Atur anggaran · Ubah · Lepas pin** (D-012, D-062, D-069);
/// an income row's has no Atur anggaran. When a group has no budget, the hero offers a quiet
/// "Atur anggaran" link to Atur kartu, where budgets are set (D-069).
struct HomeView: View {
    /// What the sheet shows.
    enum SheetRoute: Identifiable {
        /// "+": a new transaction, nothing preselected.
        case add
        /// A pinned card's quick add.
        case quickAdd(Subcategory)
        /// Atur: pin, unpin and reorder the cards.
        case pins
        /// A card's **Ubah**: the subcategory editor (D-062), with the subcategory read when it was tapped,
        /// since the editor can delete it while the sheet is still up.
        case editSubcategory(SubcategoryEditorSheet.Edited)
        /// A card's **Atur anggaran**: the subcategory's budget keypad (D-069).
        case budget(BudgetTarget)

        var id: String {
            switch self {
            case .add: "add"
            case .quickAdd(let subcategory): "quickAdd-\(subcategory.id)"
            case .pins: "pins"
            case .editSubcategory(let edited): "editSubcategory-\(edited.id)"
            case .budget(let target): "budget-\(target.id)"
            }
        }
    }

    @State private var current = CurrentMonth.now
    @State private var sheet: SheetRoute?
    /// A card's **Lihat detail**: the subcategory's detail for the current month (D-051).
    @State private var detail: SubcategoryDetailRoute?
    /// The hero's tap: this month's transactions (D-068).
    @State private var monthList: MonthTransactionsRoute?

    var body: some View {
        NavigationStack {
            HomeContent(
                month: current.month,
                timeZone: current.timeZone,
                onQuickAdd: { sheet = .quickAdd($0) },
                onShowDetail: { detail = SubcategoryDetailRoute(subcategory: $0, month: current.month, timeZone: current.timeZone) },
                onEdit: { sheet = .editSubcategory(SubcategoryEditorSheet.Edited($0)) },
                onSetBudget: { sheet = .budget(.subcategory($0)) },
                onManagePins: { sheet = .pins },
                onShowMonth: { monthList = MonthTransactionsRoute(month: current.month, timeZone: current.timeZone) }
            )
            .navigationDestination(item: $detail) { route in
                SubcategoryDetailView(route: route)
            }
            .navigationDestination(item: $monthList) { route in
                MonthTransactionsView(route: route)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sheet = .add
                    } label: {
                        Label {
                            Text(
                                "Catat transaksi",
                                comment: "Logging a new transaction: the add sheet's title and the VoiceOver label of the + button that opens it."
                            )
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    .accessibilityIdentifier("home.add")
                }
            }
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .add: AddTransactionSheet()
            case .quickAdd(let subcategory): AddTransactionSheet(mode: .preselected(subcategory))
            case .pins: PinManagerSheet()
            case .editSubcategory(let edited): SubcategoryEditorSheet(mode: .edit(edited))
            case .budget(let target): BudgetTargetSheet(target: target)
            }
        }
        .trackingCurrentMonth($current)
    }
}

/// Home's scrolling content for one month. `@Query` keeps every number live: a save in the add sheet,
/// an unpin or a reorder shows at once. Transactions are fetched by date range only (D-018); a new
/// month or time zone from the parent re-runs `init`, which rebuilds the ranges.
private struct HomeContent: View {
    let month: MonthKey
    let timeZone: TimeZone
    let onQuickAdd: (Subcategory) -> Void
    let onShowDetail: (Subcategory) -> Void
    let onEdit: (Subcategory) -> Void
    let onSetBudget: (Subcategory) -> Void
    let onManagePins: () -> Void
    let onShowMonth: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var current: [MoneyTransaction]
    @Query private var previous: [MoneyTransaction]
    /// The month before's rollups: it is always inside the raw window today, but its totals still come
    /// from the one source (``MonthTotals``, D-055, D-059), so a store caught before retention runs or a
    /// clock set back never compares against a false Rp0.
    @Query private var previousRollups: [MonthlyRollup]
    /// Every pin is visible, because hiding unpins (D-049); same set as ``Ledger/pinnedSubcategories()``.
    @Query(
        filter: #Predicate<Subcategory> { $0.pinOrder != nil },
        sort: \Subcategory.pinOrder
    ) private var pinned: [Subcategory]
    /// The settings row, as ``AppSettings/fetchOrCreate(in:)`` picks it.
    @Query(sort: \AppSettings.seedVersion, order: .reverse) private var settings: [AppSettings]
    /// At most one row each: with neither, this is a fresh install (``Backup/isFreshInstall(_:)``, D-060).
    @Query(Backup.anyTransaction) private var anyTransaction: [MoneyTransaction]
    @Query(Backup.anyRollup) private var anyRollup: [MonthlyRollup]
    @State private var showsUnpinError = false
    /// "Pulihkan dari cadangan" from the empty state: the same flow as Pengaturan's (D-060), from `RootView`.
    @Environment(RestoreController.self) private var restore
    @State private var isPickingBackup = false

    init(
        month: MonthKey,
        timeZone: TimeZone,
        onQuickAdd: @escaping (Subcategory) -> Void,
        onShowDetail: @escaping (Subcategory) -> Void,
        onEdit: @escaping (Subcategory) -> Void,
        onSetBudget: @escaping (Subcategory) -> Void,
        onManagePins: @escaping () -> Void,
        onShowMonth: @escaping () -> Void
    ) {
        self.month = month
        self.timeZone = timeZone
        self.onQuickAdd = onQuickAdd
        self.onShowDetail = onShowDetail
        self.onEdit = onEdit
        self.onSetBudget = onSetBudget
        self.onManagePins = onManagePins
        self.onShowMonth = onShowMonth
        _current = Query(MoneyTransaction.descriptor(in: month.dateRange(in: timeZone)))
        _previous = Query(MoneyTransaction.descriptor(in: month.previous.dateRange(in: timeZone)))
        _previousRollups = Query(MonthlyRollup.descriptor(from: month.previous, through: month.previous))
    }

    var body: some View {
        let overview = overview
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                MonthSummaryCard(overview: overview, title: monthTitle, action: onShowMonth, onSetBudget: onManagePins) {
                    restoreLink
                }
                cardsSection(overview)
                incomeSection(overview)
            }
            .padding(16)
            .fileImporter(isPresented: $isPickingBackup, allowedContentTypes: [.json]) { result in
                restore.open(result, from: .home)
            }
            // Onboarding's "Pulihkan dari cadangan" (D-063) lands here once the introduction is gone.
            .onChange(of: restore.pickerRequest, initial: true) {
                if restore.takePickerRequest(for: .home) { isPickingBackup = true }
            }
        }
        .accessibilityIdentifier("home.scroll")
        .foregroundStyle(Color(.textPrimary))
        .background(Color(.appBackground).ignoresSafeArea())
        .alert(
            Text("Belum terlepas", comment: "Alert title when unpinning a card from Home failed."),
            isPresented: $showsUnpinError
        ) {
            Button {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: {
            Text("Coba lepas sekali lagi ya.", comment: "Alert message when unpinning a card failed: asks to try again.")
        }
    }

    private var overview: HomeOverview {
        let budgets: [ExpenseGroup: Int64] = settings.first.map { settings in
            ExpenseGroup.allCases.reduce(into: [:]) { result, group in result[group] = settings.budget(for: group) }
        } ?? [:]
        let lastMonth = MonthTotals(
            transactions: previous.map(TransactionSnapshot.init),
            rollups: previousRollups.compactMap(RollupSnapshot.init),
            timeZone: timeZone
        ).summary(for: month.previous)
        return HomeOverview(
            current: current.map(TransactionSnapshot.init),
            previous: lastMonth,
            pins: pinned.map { HomeOverview.Pin(id: $0.id, monthlyBudget: $0.monthlyBudget) },
            groupBudgets: budgets
        )
    }

    private var header: some View {
        Text(verbatim: AppInfo.name)
            .font(.brandTitle)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("root.title")
    }

    /// "November 2026", in the app language (the hero's title, D-068).
    private var monthTitle: String {
        month.start(in: timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
    }

    // MARK: - Restore

    /// On a fresh install (no transactions, no rollups; the seed doesn't count), the empty state offers to
    /// restore a backup, e.g. after reinstalling (D-019, D-060). A failed attempt stays explained here.
    @ViewBuilder private var restoreLink: some View {
        let isFresh = anyTransaction.isEmpty && anyRollup.isEmpty
        let status = restore.status(for: .home)
        if isFresh || status != .idle {
            VStack(alignment: .leading, spacing: 4) {
                if isFresh {
                    Button {
                        isPickingBackup = true
                    } label: {
                        Label {
                            Text("Pulihkan dari cadangan", comment: "Restores all data from a backup file: Pengaturan's row, the link in Home's empty state on a fresh install, and onboarding's last page.")
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.brand))
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("home.restore")
                }
                RestoreStatusText(status: status)
            }
        }
    }

    // MARK: - Cards

    /// Pinned subcategories of one Home section, in pin order (D-068).
    private func pins(in section: PinSection) -> [Subcategory] {
        pinned.filter { $0.pinSection == section }
    }

    private func cardsSection(_ overview: HomeOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Catat cepat", comment: "Header above Home's pinned subcategory cards: tapping a card logs into it.")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    onManagePins()
                } label: {
                    Text("Atur", comment: "Button above Home's pinned cards that opens pin management (pin, unpin, reorder).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.brand))
                        .frame(minHeight: 44)
                }
                .accessibilityLabel(Text("Atur kartu", comment: "Title of the pin management sheet, and VoiceOver label of the Atur button that opens it."))
                .accessibilityIdentifier("home.managePins")
            }
            columns(overview)
        }
    }

    /// Kebutuhan on the left, Keinginan on the right, top-aligned, each in pin order; they may differ in
    /// length (D-068). From the accessibility text sizes up they stack, needs first, at full width.
    private func columns(_ overview: HomeOverview) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            column(.kebutuhan, overview: overview)
            column(.keinginan, overview: overview)
        }
    }

    private func column(_ section: PinSection, overview: HomeOverview) -> some View {
        let subcategories = pins(in: section)
        return VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.textSecondary))
                .accessibilityAddTraits(.isHeader)
            if subcategories.isEmpty {
                PinPlaceholderCard(action: onManagePins)
                    .accessibilityLabel(Text(LocalizedStringResource(
                        "home.pinPlaceholder.accessibilityLabel",
                        defaultValue: "Pin \(String(localized: section.title))",
                        comment: "VoiceOver label of the dashed '+ Pin' placeholder in an empty Home column (D-068). The placeholder is Kebutuhan or Keinginan."
                    )))
                    .accessibilityHint(Text(
                        "Membuka Atur kartu.",
                        comment: "VoiceOver hint on the dashed '+ Pin' placeholder in an empty Home column: it opens pin management (D-068)."
                    ))
                    .accessibilityIdentifier("home.pinPlaceholder.\(section.rawValue)")
            } else {
                ForEach(subcategories) { subcategory in
                    card(for: subcategory, numbers: overview.card(for: subcategory.id))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func card(for subcategory: Subcategory, numbers: HomeOverview.Card?) -> some View {
        SubcategoryCard(
            emoji: subcategory.emoji,
            name: subcategory.name,
            tint: CategoryTint(kind: subcategory.kind, group: subcategory.group),
            thisMonth: numbers?.comparison.current ?? 0,
            lastMonth: numbers?.comparison.previous ?? 0,
            budget: numbers?.budget
        ) {
            onQuickAdd(subcategory)
        } contextMenu: {
            menuItems(for: subcategory)
        }
        .accessibilityHint(Self.quickAddHint)
        .accessibilityIdentifier("home.card.\(subcategory.name)")
    }

    // MARK: - Income

    /// Pinned income as thin full-width rows in one block, in pin order; hidden when none is pinned (D-068).
    @ViewBuilder private func incomeSection(_ overview: HomeOverview) -> some View {
        let income = pins(in: .pemasukan)
        if !income.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(PinSection.pemasukan.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.textSecondary))
                    .accessibilityAddTraits(.isHeader)
                PinnedIncomeBlock {
                    ForEach(income) { subcategory in
                        PinnedIncomeRow(
                            emoji: subcategory.emoji,
                            name: subcategory.name,
                            thisMonth: overview.card(for: subcategory.id)?.comparison.current ?? 0
                        ) {
                            onQuickAdd(subcategory)
                        } contextMenu: {
                            menuItems(for: subcategory)
                        }
                        .accessibilityHint(Self.quickAddHint)
                        .accessibilityIdentifier("home.income.\(subcategory.name)")
                    }
                }
            }
        }
    }

    private static var quickAddHint: Text {
        Text("Ketuk untuk mencatat.", comment: "VoiceOver hint on a Home card: tapping it opens the add sheet with this subcategory selected.")
    }

    /// The long-press menu of a card, **Lihat detail · Atur anggaran · Ubah · Lepas pin**, or of an income
    /// row, without Atur anggaran: income has no budget (D-005, D-012, D-062, D-069).
    @ViewBuilder private func menuItems(for subcategory: Subcategory) -> some View {
        Button {
            onShowDetail(subcategory)
        } label: {
            Label {
                Text("Lihat detail", comment: "Card menu item and VoiceOver action that opens the subcategory's detail for this month (D-012, D-051).")
            } icon: {
                Image(systemName: "chart.pie")
            }
        }
        .accessibilityIdentifier("home.card.detail")
        if subcategory.kind == .expense {
            Button {
                onSetBudget(subcategory)
            } label: {
                Label {
                    Text(BudgetCopy.setBudget)
                } icon: {
                    Image(systemName: "gauge.with.needle")
                }
            }
            .accessibilityIdentifier("home.card.budget")
        }
        Button {
            onEdit(subcategory)
        } label: {
            Label {
                Text("Ubah", comment: "Opens something for editing: a transaction row's swipe action, and the Home card menu item that edits the card's subcategory (D-044: editing is 'Ubah' everywhere).")
            } icon: {
                Image(systemName: "pencil")
            }
        }
        .accessibilityIdentifier("home.card.edit")
        Button {
            unpin(subcategory)
        } label: {
            Label {
                Text("Lepas pin", comment: "Card menu item and VoiceOver action that removes a pinned subcategory card from Home.")
            } icon: {
                Image(systemName: "pin.slash")
            }
        }
        .accessibilityIdentifier("home.card.unpin")
    }

    private func unpin(_ subcategory: Subcategory) {
        do {
            try withAnimation {
                try Ledger(context: context, timeZone: .autoupdatingCurrent).unpin(subcategory)
            }
        } catch {
            HomeLog.logger.error("Unpinning failed: \(error.localizedDescription, privacy: .public)")
            showsUnpinError = true
        }
    }
}

/// The Home feature's log.
enum HomeLog {
    static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "Home")
}

#if DEBUG
#Preview("With data") {
    HomeView()
        .modelContainer(PreviewStore.makeContainer())
        .environment(RestoreController())
}

#Preview("Empty") {
    HomeView()
        .modelContainer(PreviewStore.makeContainer(withSamples: false))
        .environment(RestoreController())
}
#endif
