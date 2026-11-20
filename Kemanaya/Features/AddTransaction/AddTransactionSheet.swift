import KemanayaCore
import OSLog
import SwiftData
import SwiftUI

/// The add / edit sheet (D-013, D-043, D-044): kind switch, big amount, rupiah keypad, optional note
/// and date, and the subcategory grid. Every rule lives in ``AddDraft`` (KemanayaCore); this view
/// draws it, forwards input and runs the save.
///
/// - **Add** (`.add`, the "+" button): tapping a subcategory saves at once ("+" → amount → subcategory).
/// - **Selected subcategory** (`.preselected`, `.edit`): tapping another tile selects it; tapping the
///   highlighted tile or Simpan saves.
///
/// Saving plays the success haptic and dismisses, with no celebration (D-022).
struct AddTransactionSheet: View {
    enum Mode {
        /// A new transaction; tapping a subcategory saves.
        case add
        /// A new transaction with this subcategory highlighted (Phase 5 pinned-card quick add).
        /// A hidden subcategory is not highlighted (``AddDraft/preselected(_:isHidden:now:)``).
        case preselected(Subcategory)
        /// Edits this transaction, everything prefilled.
        case edit(MoneyTransaction)
    }

    /// Why a save didn't happen, for the alert.
    private enum SaveProblem {
        /// A rule refused it; the message says which (S6: never "try again" for something that can't work).
        case rejected(TransactionError)
        /// SwiftData failed to save; trying again may work.
        case saveFailed
        /// The tapped subcategory is no longer in the grid (it was hidden or deleted meanwhile).
        case subcategoryMissing
    }

    private let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var draft: AddDraft
    @State private var sections: [SubcategorySection] = []
    /// Bumped by every grid load, so the standard layout can bring the selected tile into view once loaded.
    @State private var sectionsLoadCount = 0
    /// Whether the first grid load has run its scroll to the selected tile, so later loads don't jump.
    @State private var hasRevealedSelection = false
    /// Set before a save starts and cleared only if it fails, so a second tap during the dismiss
    /// animation can't save twice.
    @State private var isSaving = false
    @State private var problem: SaveProblem?
    @State private var savedCount = 0
    @State private var rejectedKeyCount = 0
    @FocusState private var isNoteFocused: Bool

    /// Minimum tile width: four columns on every iPhone at default sizes, fewer as text grows.
    @ScaledMetric(relativeTo: .footnote) private var tileMinimumWidth: CGFloat = 76

    /// - Parameter mode: `.add` for "+"; `.preselected(subcategory)` for a pinned card's quick add (Phase 5),
    ///   which needs nothing else; `.edit(transaction)` for swipe → Ubah.
    init(mode: Mode = .add) {
        self.mode = mode
        let draft: AddDraft = switch mode {
        case .add:
            .add(now: .now)
        case .preselected(let subcategory):
            .preselected(Self.pick(subcategory), isHidden: subcategory.isHidden, now: .now)
        case .edit(let transaction):
            .edit(
                amount: transaction.amount,
                kind: transaction.kind,
                subcategory: transaction.subcategory.map(Self.pick),
                date: transaction.date,
                note: transaction.note
            )
        }
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Group {
                if usesScrollingLayout {
                    scrollingLayout
                } else {
                    standardLayout
                }
            }
            .disabled(isSaving)
            .foregroundStyle(Color(.textPrimary))
            .background(Color(.appBackground).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.warning, trigger: rejectedKeyCount)
        .onAppear(perform: loadSections)
        .onChange(of: draft.kind) { loadSections() }
        .alert(
            problemTitle,
            isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } }),
            presenting: problem
        ) { _ in
            Button {} label: { Text("OK", comment: "Dismisses an alert.") }
        } message: { problem in
            problemMessage(problem)
        }
    }

    // MARK: - Layouts

    /// Kind switch and amount fixed on top; note / date and the grid scrolling in the middle; the keypad
    /// fixed at the bottom within thumb reach. Only the middle gives way. On an iPhone SE (667 pt) that
    /// leaves about 220 pt, enough for note / date, the hint, the Kebutuhan header and the first full
    /// row of tiles (Makan first). While the note is being typed the keypad steps aside, so the note
    /// stays visible above the keyboard.
    private var standardLayout: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                kindPicker
                amountDisplay
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .fixedSize(horizontal: false, vertical: true)

            revealingSelection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        details
                        grid
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.immediately)
                .accessibilityIdentifier("add.scroll")
            }

            if !isNoteFocused {
                keypad
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isNoteFocused)
    }

    /// From XX Large text up, the fixed keypad would leave the grid no room, so everything scrolls
    /// as one column: amount, keypad, note / date, then the grid. It always opens at the top, so the
    /// amount and keypad are in view; the label under the amount names the selected subcategory (D-047).
    private var scrollingLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kindPicker
                amountDisplay
                keypad
                details
                grid
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier("add.scroll")
    }

    /// Standard layout only: opening with a selected subcategory (edit, pinned-card quick add) scrolls
    /// the grid once, without animation, so the highlighted tile is in view even when it sits far down
    /// (a Keinginan tile). Later reloads (switching kind) leave the scroll position alone (D-047).
    private func revealingSelection(@ViewBuilder _ scrollView: () -> some View) -> some View {
        let scrollView = scrollView()
        return ScrollViewReader { proxy in
            scrollView
                .onChange(of: sectionsLoadCount) {
                    guard !hasRevealedSelection else { return }
                    hasRevealedSelection = true
                    guard let id = selectedSubcategory?.id else { return }
                    proxy.scrollTo(id, anchor: .center)
                }
        }
    }

    // MARK: - Pieces

    private var kindPicker: some View {
        Picker(selection: $draft.kind) {
            ForEach(TransactionKind.allCases, id: \.self) { kind in
                Text(kind.title).tag(kind)
            }
        } label: {
            Text("Jenis transaksi", comment: "Accessibility label of the expense/income switch in the add sheet.")
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("add.kind")
    }

    /// The amount, its clear button, and under it the selected subcategory when there is one (D-047).
    private var amountDisplay: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                AmountText(draft.entry.amount, size: .hero)
                    .foregroundStyle(draft.entry.isEmpty ? Color(.textSecondary) : Color(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("add.amount")
                if !draft.entry.isEmpty {
                    Button {
                        draft.entry.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(.textSecondary))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(Text("Kosongkan jumlah", comment: "VoiceOver label for the button that clears the typed amount back to 0."))
                    .accessibilityIdentifier("add.clear")
                }
            }
            if let selected = selectedSubcategory {
                selectedLabel(selected)
            }
        }
    }

    /// "☕ Kopi" on the tile's own tinted surface, so it reads as the highlighted tile. One line in the
    /// standard layout, which keeps the grid's height; up to three lines in the scrolling layout, where a
    /// long name at AX5 has the room. VoiceOver reads "Dipilih: Kopi"; the emoji is decoration, as on the tile.
    private func selectedLabel(_ subcategory: Subcategory) -> some View {
        let tint = CategoryTint(kind: subcategory.kind, group: subcategory.group)
        return Text(verbatim: "\(subcategory.emoji) \(subcategory.name)")
            .font(.subheadline.weight(.semibold))
            .lineLimit(usesScrollingLayout ? 3 : 1)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(Color(tint.content))
            .background(Color(tint.surface), in: .rect(cornerRadius: 10, style: .continuous))
            .accessibilityLabel(Text(
                "Dipilih: \(subcategory.name)",
                comment: "VoiceOver label of the add / edit sheet's label under the amount that names the selected subcategory, e.g. 'Dipilih: Kopi'. The placeholder is the subcategory name (user data)."
            ))
            .accessibilityIdentifier("add.selected")
    }

    private var keypad: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(KeypadInput.rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { key in
                        KeypadKey(key) { press(key) }
                            .accessibilityIdentifier(Self.identifier(for: key))
                    }
                }
            }
        }
    }

    /// Note and date: optional, compact, never needed for the 3-tap path (D-013).
    private var details: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            TextField(
                text: $draft.note,
                prompt: Text("Catatan (opsional)", comment: "Placeholder of the optional note field in the add sheet.")
            ) {
                Text("Catatan", comment: "Accessibility label of the optional note field in the add sheet.")
            }
            .focused($isNoteFocused)
            .submitLabel(.done)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Color(.surface), in: .rect(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("add.note")

            DatePicker(
                selection: Binding(get: { draft.date }, set: { draft.setDate($0) }),
                in: dateRange,
                displayedComponents: .date
            ) {
                Text("Tanggal", comment: "Accessibility label of the date picker in the add sheet.")
            }
            .labelsHidden()
            .fixedSize()
            // Months are Gregorian everywhere (MonthKey), so "end of this month" means the same in the picker.
            .environment(\.calendar, .gregorian(in: .autoupdatingCurrent))
            .accessibilityIdentifier("add.date")
        }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !draft.savesWithButton {
                // Always laid out, only faded, so the tiles don't jump under the thumb on the first digit.
                Text("Ketik jumlahnya dulu, lalu pilih kategorinya.", comment: "Hint above the subcategory grid while no amount is typed yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(draft.entry.isEmpty ? 1 : 0)
                    .accessibilityHidden(!draft.entry.isEmpty)
            }
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    if let group = section.group {
                        Text(group.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.textSecondary))
                            .accessibilityAddTraits(.isHeader)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tileMinimumWidth), spacing: 8)], spacing: 8) {
                        ForEach(section.subcategories) { subcategory in
                            tile(for: subcategory)
                        }
                    }
                }
            }
        }
    }

    private func tile(for subcategory: Subcategory) -> some View {
        let pick = Self.pick(subcategory)
        let saves = draft.tapSaves(pick)
        return SubcategoryTile(
            emoji: subcategory.emoji,
            name: subcategory.name,
            tint: CategoryTint(kind: subcategory.kind, group: subcategory.group),
            isSelected: draft.selection == pick,
            accessibilityValue: saves ? Self.amountText(draft.entry.amount) : nil,
            accessibilityHint: saves
                ? Text("Ketuk untuk menyimpan.", comment: "VoiceOver hint on a subcategory tile whose tap saves the typed amount into it.")
                : nil
        ) {
            tap(pick)
        }
        .disabled(draft.tilesDisabled)
        .accessibilityIdentifier("add.tile.\(subcategory.name)")
        .id(subcategory.id)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                dismiss()
            } label: {
                Text("Batal", comment: "Cancels: closes the add sheet without saving, the delete dialog without deleting, or the restore alert without restoring.")
            }
            .accessibilityIdentifier("add.cancel")
        }
        if draft.savesWithButton {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if let pick = draft.selectedOfCurrentKind { save(to: pick.id) }
                } label: {
                    Text("Simpan", comment: "Saves the transaction in the add / edit sheet.")
                }
                .disabled(!draft.canSave || isSaving)
                .accessibilityIdentifier("add.save")
            }
        }
    }

    // MARK: - Derived

    private var title: Text {
        if case .edit = mode {
            Text("Ubah transaksi", comment: "Title of the sheet when editing an existing transaction.")
        } else {
            Text(
                "Catat transaksi",
                comment: "Logging a new transaction: the add sheet's title and the VoiceOver label of the + button that opens it."
            )
        }
    }

    private var ledger: Ledger {
        Ledger(context: context, timeZone: .autoupdatingCurrent)
    }

    /// The D-017 window start through the end of this month (D-044).
    private var dateRange: ClosedRange<Date> {
        RetentionWindow.entryDates(now: .now, timeZone: .autoupdatingCurrent, keeping: draft.originalDate)
    }

    /// The selected subcategory of the kind on screen, for the label under the amount. None when nothing
    /// is selected, which includes a hidden preselected subcategory (``AddDraft/preselected(_:isHidden:now:)``).
    private var selectedSubcategory: Subcategory? {
        draft.selectedOfCurrentKind.flatMap { subcategory(withID: $0.id) }
    }

    private var usesScrollingLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    private var problemTitle: Text {
        if case .saveFailed = problem {
            Text("Belum tersimpan", comment: "Alert title when saving a transaction failed and trying again may work.")
        } else {
            Text("Belum bisa disimpan", comment: "Alert title when a transaction can't be saved as entered.")
        }
    }

    private func problemMessage(_ problem: SaveProblem) -> Text {
        switch problem {
        case .saveFailed:
            Text("Coba simpan sekali lagi ya.", comment: "Alert message when saving a transaction failed: asks to try again.")
        case .rejected(.amountNotPositive):
            Text("Ketik jumlahnya dulu ya.", comment: "Alert message when saving without an amount.")
        case .rejected(.subcategoryHidden), .subcategoryMissing:
            Text(
                "Kategori ini sudah disembunyikan. Pilih kategori lain ya.",
                comment: "Alert message when the chosen subcategory was hidden, so it can't take new transactions."
            )
        case .rejected(.dateAfterCurrentMonth):
            Text(
                "Tanggalnya paling jauh akhir bulan ini.",
                comment: "Alert message when the date is in a later month: entries can be dated up to the end of the current month."
            )
        case .rejected(.dateBeforeRawWindow):
            Text(
                "Tanggalnya terlalu lama. Catatan bisa mundur sampai 12 bulan sebelum bulan ini.",
                comment: "Alert message when a new entry's date is too far back: entries can go back to the start of the month 12 months before the current one."
            )
        }
    }

    // MARK: - Actions

    private func press(_ key: KeypadInput) {
        switch draft.entry.press(key) {
        case .accepted:
            if voiceOverEnabled {
                AccessibilityNotification.Announcement(Self.amountString(draft.entry.amount)).post()
            }
        case .rejectedAtCap:
            rejectedKeyCount += 1
        case .ignored:
            break
        }
    }

    private func tap(_ pick: AddDraft.Pick) {
        guard !isSaving else { return }
        switch draft.tap(pick) {
        case .save(let id): save(to: id)
        case .selected, .ignored: break
        }
    }

    private func save(to id: UUID) {
        guard !isSaving else { return }
        guard let subcategory = subcategory(withID: id) else {
            problem = .subcategoryMissing
            return
        }
        isSaving = true
        let now = Date.now
        let date = draft.dateToSave(now: now, timeZone: .autoupdatingCurrent)
        do {
            if case .edit(let transaction) = mode {
                try ledger.updateTransaction(transaction, amount: draft.entry.amount, subcategory: subcategory, date: date, note: draft.note, now: now)
            } else {
                try ledger.addTransaction(amount: draft.entry.amount, subcategory: subcategory, date: date, note: draft.note, now: now)
            }
            savedCount += 1
            dismiss()
        } catch let error as TransactionError {
            isSaving = false
            problem = .rejected(error)
        } catch {
            Self.logger.error("Saving a transaction failed: \(error.localizedDescription, privacy: .public)")
            isSaving = false
            problem = .saveFailed
        }
    }

    /// The subcategory with this id in the grid on screen.
    private func subcategory(withID id: UUID) -> Subcategory? {
        sections.lazy.flatMap(\.subcategories).first { $0.id == id }
    }

    private func loadSections() {
        do {
            sections = try ledger.gridSections(for: draft.kind, including: draft.includedHiddenSubcategoryID)
        } catch {
            Self.logger.error("Loading subcategories failed: \(error.localizedDescription, privacy: .public)")
            sections = []
        }
        sectionsLoadCount += 1
    }

    // MARK: - Helpers

    private static let logger = Logger(subsystem: "com.afgaghifari.kemanaya", category: "AddTransaction")

    private static func pick(_ subcategory: Subcategory) -> AddDraft.Pick {
        AddDraft.Pick(id: subcategory.id, kind: subcategory.kind)
    }

    /// Same catalog key and comment as ``AmountText``'s VoiceOver label.
    private static func amountText(_ amount: Int64) -> Text {
        Text("\(amount) rupiah", comment: "VoiceOver reading of a money amount. The number is whole rupiah, without separators.")
    }

    private static func amountString(_ amount: Int64) -> String {
        String(localized: "\(amount) rupiah", comment: "VoiceOver reading of a money amount. The number is whole rupiah, without separators.")
    }

    /// `add.key.0` … `add.key.9`, `add.key.000`, `add.key.backspace`, for UI tests.
    private static func identifier(for key: KeypadInput) -> String {
        switch key {
        case .digit(let digit): "add.key.\(digit)"
        case .tripleZero: "add.key.000"
        case .backspace: "add.key.backspace"
        }
    }
}

#if DEBUG
#Preview("Add") {
    AddTransactionSheet()
        .modelContainer(PreviewStore.makeContainer())
}

#Preview("Edit") {
    let container = PreviewStore.makeContainer()
    let transaction = try? container.mainContext.fetch(FetchDescriptor<MoneyTransaction>()).first
    return Group {
        if let transaction {
            AddTransactionSheet(mode: .edit(transaction))
        }
    }
    .modelContainer(container)
}
#endif
