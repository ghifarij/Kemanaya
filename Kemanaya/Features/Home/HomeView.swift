import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// The Beranda tab, the app's root (D-012, D-014, D-048): the month's totals, sisa and savings rate,
/// the Kebutuhan / Keinginan split, budgets where set, and the pinned cards. "+" in the toolbar opens
/// the add sheet; a card opens it with its subcategory preselected; **Atur** opens pin management.
struct HomeView: View {
    /// What the sheet shows.
    enum SheetRoute: Identifiable {
        /// "+": a new transaction, nothing preselected.
        case add
        /// A pinned card's quick add.
        case quickAdd(Subcategory)
        /// Atur: pin, unpin and reorder the cards.
        case pins

        var id: String {
            switch self {
            case .add: "add"
            case .quickAdd(let subcategory): "quickAdd-\(subcategory.id)"
            case .pins: "pins"
            }
        }
    }

    @State private var current = CurrentMonth.now
    @State private var sheet: SheetRoute?
    /// A card's **Lihat detail**: the subcategory's detail for the current month (D-051).
    @State private var detail: SubcategoryDetailRoute?

    var body: some View {
        NavigationStack {
            HomeContent(
                month: current.month,
                timeZone: current.timeZone,
                onQuickAdd: { sheet = .quickAdd($0) },
                onShowDetail: { detail = SubcategoryDetailRoute(subcategory: $0, month: current.month, timeZone: current.timeZone) },
                onManagePins: { sheet = .pins }
            )
            .navigationDestination(item: $detail) { route in
                SubcategoryDetailView(route: route)
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
    let onManagePins: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var current: [MoneyTransaction]
    @Query private var previous: [MoneyTransaction]
    /// Every pin is visible, because hiding unpins (D-049); same set as ``Ledger/pinnedSubcategories()``.
    @Query(
        filter: #Predicate<Subcategory> { $0.pinOrder != nil },
        sort: \Subcategory.pinOrder
    ) private var pinned: [Subcategory]
    /// The settings row, as ``AppSettings/fetchOrCreate(in:)`` picks it.
    @Query(sort: \AppSettings.seedVersion, order: .reverse) private var settings: [AppSettings]
    @State private var showsUnpinError = false

    init(
        month: MonthKey,
        timeZone: TimeZone,
        onQuickAdd: @escaping (Subcategory) -> Void,
        onShowDetail: @escaping (Subcategory) -> Void,
        onManagePins: @escaping () -> Void
    ) {
        self.month = month
        self.timeZone = timeZone
        self.onQuickAdd = onQuickAdd
        self.onShowDetail = onShowDetail
        self.onManagePins = onManagePins
        _current = Query(MoneyTransaction.descriptor(in: month.dateRange(in: timeZone)))
        _previous = Query(MoneyTransaction.descriptor(in: month.previous.dateRange(in: timeZone)))
    }

    var body: some View {
        let overview = overview
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                MonthSummaryCard(overview: overview)
                cardsSection(overview)
            }
            .padding(16)
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
        return HomeOverview(
            current: current.map(TransactionSnapshot.init),
            previous: previous.map(TransactionSnapshot.init),
            pins: pinned.map { HomeOverview.Pin(id: $0.id, monthlyBudget: $0.monthlyBudget) },
            groupBudgets: budgets
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: AppInfo.name)
                .font(.brandTitle)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("root.title")
            Text(month.start(in: timeZone), format: Date.FormatStyle.gregorian(locale: locale, timeZone: timeZone).month(.wide).year())
                .font(.subheadline)
                .foregroundStyle(Color(.textSecondary))
                .accessibilityIdentifier("home.month")
        }
    }

    // MARK: - Cards

    private func cardsSection(_ overview: HomeOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Catat cepat", comment: "Header above Home's pinned subcategory cards: tapping a card logs into it.")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button(action: onManagePins) {
                    Text("Atur", comment: "Button above Home's pinned cards that opens pin management (pin, unpin, reorder).")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.brand))
                        .frame(minHeight: 44)
                }
                .accessibilityLabel(Text("Atur kartu", comment: "Title of the pin management sheet, and VoiceOver label of the Atur button that opens it."))
                .accessibilityIdentifier("home.managePins")
            }
            if pinned.isEmpty {
                noCards
            } else {
                cardGrid(overview)
            }
        }
    }

    /// Two columns (D-012), one from the accessibility text sizes up, so amounts keep their size.
    private func cardGrid(_ overview: HomeOverview) -> some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: pinned.count, by: columns).map { Array(pinned[$0..<min($0 + columns, pinned.count)]) }
        // A `Grid`, not a lazy one: at most nine cards, and every card in a row takes the row's height.
        return Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(rows, id: \.first?.id) { row in
                GridRow {
                    ForEach(row) { subcategory in
                        card(for: subcategory, numbers: overview.card(for: subcategory.id))
                    }
                    if row.count < columns {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
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
        .accessibilityHint(Text("Ketuk untuk mencatat.", comment: "VoiceOver hint on a Home card: tapping it opens the add sheet with this subcategory selected."))
        .accessibilityIdentifier("home.card.\(subcategory.name)")
    }

    /// Every card unpinned: say where they come back from. Calm, no judgment (D-022).
    private var noCards: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Belum ada kartu", comment: "Home, when no subcategory is pinned: title.")
                .font(.subheadline.weight(.semibold))
            Text(
                "Ketuk Atur untuk memilih kategori yang sering kamu catat.",
                comment: "Home, when no subcategory is pinned: tap Atur to choose the subcategories logged most often."
            )
            .font(.subheadline)
            .foregroundStyle(Color(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(.textSecondary).opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.cards.empty")
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
}

#Preview("Empty") {
    HomeView()
        .modelContainer(PreviewStore.makeContainer(withSamples: false))
}
#endif
