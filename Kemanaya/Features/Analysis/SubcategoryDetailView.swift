import KemanayaCore
import SwiftData
import SwiftUI

/// Where a subcategory detail opens: from an Analisis ranked row (the selected month) or a pinned
/// card's **Lihat detail** (the current month) (D-051).
struct SubcategoryDetailRoute: Hashable {
    let subcategory: Subcategory
    let month: MonthKey
    /// The device zone the month was bucketed in, by identifier so the route stays `Hashable`.
    let timeZoneID: String

    init(subcategory: Subcategory, month: MonthKey, timeZone: TimeZone) {
        self.subcategory = subcategory
        self.month = month
        self.timeZoneID = timeZone.identifier
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .autoupdatingCurrent
    }
}

/// One subcategory's month (D-041, D-051): the total, budget progress when a budget is set, the
/// comparison with the month before, and the month's transactions. Tap a transaction to change it
/// (**Ubah**, the add/edit sheet); swipe for **Hapus** or **Ubah**, as in Riwayat.
///
/// The comparison is a neutral fact, "Naik Rp35.000 dari Oktober 2026", in the secondary colour:
/// no praise for spending less, no alarm for more (D-022).
struct SubcategoryDetailView: View {
    let route: SubcategoryDetailRoute

    @Environment(\.locale) private var locale
    @Query private var current: [MoneyTransaction]
    @Query private var previous: [MoneyTransaction]
    @State private var editing: MoneyTransaction?
    @State private var pendingDelete: PendingTransactionDelete?

    init(route: SubcategoryDetailRoute) {
        self.route = route
        let id = route.subcategory.id
        _current = Query(MoneyTransaction.descriptor(in: route.month.dateRange(in: route.timeZone), filter: .subcategory(id)))
        _previous = Query(MoneyTransaction.descriptor(in: route.month.previous.dateRange(in: route.timeZone), filter: .subcategory(id)))
    }

    private var subcategory: Subcategory { route.subcategory }

    var body: some View {
        let detail = SubcategoryDetail(
            subcategoryID: subcategory.id,
            current: current.map(TransactionSnapshot.init),
            previous: previous.map(TransactionSnapshot.init),
            monthlyBudget: subcategory.monthlyBudget
        )
        List {
            SubcategoryDetailHeader(
                detail: detail,
                tint: CategoryTint(kind: subcategory.kind, group: subcategory.group),
                monthTitle: title(of: route.month),
                previousMonthTitle: title(of: route.month.previous)
            )
            // The subcategory's card colours, as on Home (D-040): every text and mark pair is tested there.
            .listRowBackground(Color(CategoryTint(kind: subcategory.kind, group: subcategory.group).surface))
            if current.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(current) { transaction in
                        row(for: transaction)
                    }
                } header: {
                    Text("Transaksi", comment: "Subcategory detail: header above the month's transactions.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.appBackground).ignoresSafeArea())
        .foregroundStyle(Color(.textPrimary))
        .accessibilityIdentifier("detail.list")
        .navigationTitle(Text(verbatim: "\(subcategory.emoji) \(subcategory.name)"))
        .navigationBarTitleDisplayMode(.inline)
        .transactionDeleteAlert($pendingDelete)
        .sheet(item: $editing) { transaction in
            AddTransactionSheet(mode: .edit(transaction))
        }
    }

    private func row(for transaction: MoneyTransaction) -> some View {
        Button {
            editing = transaction
        } label: {
            TransactionRow(transaction: transaction)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.surface))
        .accessibilityHint(Text("Ketuk untuk mengubah.", comment: "VoiceOver hint on a transaction in the subcategory detail: tapping opens it for editing (Ubah)."))
        .accessibilityIdentifier("detail.row")
        .transactionSwipeActions {
            editing = transaction
        } onDelete: {
            pendingDelete = PendingTransactionDelete(transaction)
        }
    }

    /// Nothing logged in the subcategory this month: calm, never a verdict (D-022).
    private var emptyState: some View {
        Text(
            "Belum ada catatan di \(subcategory.name) pada \(title(of: route.month)).",
            comment: "Subcategory detail when the month has no transactions in it. 1: subcategory name, e.g. Kopi, 2: the month, e.g. November 2026."
        )
        .font(.subheadline)
        .foregroundStyle(Color(.textSecondary))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("detail.empty")
    }

    private func title(of month: MonthKey) -> String {
        month.start(in: route.timeZone).formatted(Date.FormatStyle.gregorian(locale: locale, timeZone: route.timeZone).month(.wide).year())
    }
}

/// The detail's numbers on the subcategory's card surface: month, total and count, the comparison with
/// the month before, and the budget.
private struct SubcategoryDetailHeader: View {
    let detail: SubcategoryDetail
    let tint: CategoryTint
    let monthTitle: String
    let previousMonthTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: monthTitle)
                    .font(.subheadline)
                    .foregroundStyle(Color(tint.secondaryContent))
                AmountText(detail.total, size: .large)
                Text(
                    "\(detail.count) transaksi",
                    comment: "Subcategory detail: the number of transactions this month, e.g. '3 transaksi'."
                )
                .font(.subheadline)
                .foregroundStyle(Color(tint.secondaryContent))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("detail.total")

            VStack(alignment: .leading, spacing: 8) {
                ComparisonBars(comparison: detail.comparison, tint: tint)
                comparisonText
                    .font(.subheadline)
                    .foregroundStyle(Color(tint.secondaryContent))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("detail.comparison")

            if let budget = detail.budget {
                VStack(alignment: .leading, spacing: 6) {
                    Text(
                        "Anggaran \(budget.budget.rupiahFormatted) per bulan",
                        comment: "Subcategory detail: the subcategory's standing monthly budget, e.g. 'Anggaran Rp300.000 per bulan'."
                    )
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
                    BudgetMeter(progress: budget, tint: tint, style: .bar)
                    budget.statusText
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color(tint.secondaryContent))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Anggaran", comment: "VoiceOver label of the budget block in the subcategory detail."))
                .accessibilityValue(Text(budget.accessibilityStatus))
                .accessibilityIdentifier("detail.budget")
            }
        }
        .padding(.vertical, 8)
        .foregroundStyle(Color(tint.content))
    }

    /// "Naik Rp35.000 dari Oktober 2026 (Rp280.000)": the plain difference, then the month before's total.
    private var comparisonText: Text {
        let previous = detail.previousTotal.rupiahFormatted
        let difference = detail.difference.magnitude
        let amount = Int64(clamping: difference).rupiahFormatted
        return switch detail.comparison.direction {
        case .up: Text(
            "Naik \(amount) dari \(previousMonthTitle) (\(previous))",
            comment: "Subcategory detail: this month's total is higher than the month before. 1: the difference, e.g. Rp35.000, 2: the month before, e.g. Oktober 2026, 3: its total. Neutral: state it, never praise or blame."
        )
        case .down: Text(
            "Turun \(amount) dari \(previousMonthTitle) (\(previous))",
            comment: "Subcategory detail: this month's total is lower than the month before. 1: the difference, e.g. Rp35.000, 2: the month before, e.g. Oktober 2026, 3: its total. Neutral: state it, never praise or blame."
        )
        case .same: Text(
            "Sama dengan \(previousMonthTitle) (\(previous))",
            comment: "Subcategory detail: this month's total equals the month before's. 1: the month before, e.g. Oktober 2026, 2: its total."
        )
        }
    }
}

#if DEBUG
#Preview {
    let container = PreviewStore.makeContainer()
    let kopi = try? container.mainContext.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate { $0.name == "Kopi" })).first
    NavigationStack {
        if let kopi {
            SubcategoryDetailView(route: SubcategoryDetailRoute(subcategory: kopi, month: CurrentMonth.now.month, timeZone: .autoupdatingCurrent))
        }
    }
    .modelContainer(container)
}
#endif
