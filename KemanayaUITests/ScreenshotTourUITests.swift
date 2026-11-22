import XCTest

/// Walks the Phase 4 and Phase 5 states and attaches a screenshot of each, for the D-032 screenshot review
/// on runtimes the Xcode MCP's device tools can't drive. Each attachment is named `<variant>-<NN>-<state>`
/// (e.g. `dark-04-add-amount`) and kept, so it can be extracted from the .xcresult.
///
/// Order: Home empty (01), the Riwayat add / edit / delete flow (02–09), Home with those entries, quick add
/// and Atur with the refused-pin note (10–12b), then a relaunch with `-debugSample full` for Home with budgets (13, 13c–d) and the card menu (14).
/// Then Analisis (D-051, D-070): Lihat detail from that menu (15), the page with data (16, 16b the top 5
/// ranked rows, 16c Lihat semua and the income line, 16d the full breakdown after Lihat semua), the Keinginan filter (17), Mingguan and the six months (18, 18b), a ranked row's detail with its
/// budget (19), and a month with nothing logged, reached with the stepper (20).
/// Then Riwayat as History (D-053): the long list with month and day headers (21, 21b scrolled back to
/// older months), search results by amount (22), and the no-results state (23).
/// Then Rekap tahunan (D-059): this year to date (24, 24b months, 24c ranking) and last year, completed
/// from rollups and raw months (25, 25b ranking with a snapshot name).
/// Then Pengaturan (D-060, D-062): the top with Anggaran and Subkategori (26), the bottom with Cadangan & Ekspor
/// (no folder chosen) and Tentang (26b, where it doesn't fit). Then Phase 10 (D-062): the Kebutuhan budget sheet
/// (27), Kelola subkategori with budgets and pin glyphs (28, 28b Pemasukan), Edit mode's reorder handles (29),
/// the editor adding with an invalid name (30) and valid (30b), Ubah on a subcategory with history with its
/// hide note (31) and the hide confirmation (31b), and Ubah from a Home card's menu (32).
/// Then Phase 11 (D-063): a relaunch with `-showOnboarding` for the introduction's three pages (33, 33b,
/// 33c), and one with `-simulateStoreError exports` for the store error screen (34, 34b scrolled to the
/// bottom where it doesn't fit).
/// Shot 01's Home empty state also shows the fresh install's "Pulihkan dari cadangan" link. The Si Naya
/// empty states are shots 01 (Home), 02 (Riwayat), 20 (Analisis, a month with no spending) and 23
/// (search with no results).
///
/// The tour asserts only what it needs to reach each state; behaviour is covered by `KemanayaUITests`.
final class ScreenshotTourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Puts the simulator back in light mode, so later tests don't inherit the dark tour's appearance.
    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.appearance = .light }
        try await super.tearDown()
    }

    @MainActor
    func testTourLight() throws {
        try tour(variant: "light", appearance: .light)
    }

    @MainActor
    func testTourDark() throws {
        try tour(variant: "dark", appearance: .dark)
    }

    /// Largest accessibility Dynamic Type (AX5), light.
    @MainActor
    func testTourAX5() throws {
        try tour(
            variant: "ax5",
            appearance: .light,
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
    }

    // MARK: - The tour

    @MainActor
    private func tour(variant: String, appearance: XCUIDevice.Appearance, extraArguments: [String] = []) throws {
        XCUIDevice.shared.appearance = appearance
        launch(extraArguments)

        // 01 · Home on a fresh install: the calm empty hero and the six default cards in two columns (D-048, D-068).
        XCTAssertTrue(element("home.hero").waitForExistence(timeout: 10))
        snapshot(variant, 1, "home-empty")

        // 02 · Riwayat, nothing logged yet.
        app.tabBars.buttons["Riwayat"].tap()
        XCTAssertTrue(element("history.empty").waitForExistence(timeout: 10))
        snapshot(variant, 2, "history-empty")

        // 03 · Add sheet just opened: amount 0, the keypad up as the amount's keyboard (D-067).
        tap("history.add")
        let amount = app.staticTexts["add.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        snapshot(variant, 3, "add-opened")

        // 04 · An amount typed. Nothing is selected yet, so Simpan stays disabled.
        press(["2", "5", "000"])
        XCTAssertEqual(rupiah(amount), 25_000)
        snapshot(variant, 4, "add-amount")

        // 05 · Scrolled to the bottom of the grid (Kado is the last expense tile); dragging dismisses the
        // keypad, so the whole grid has the room. The amount is cleared first, so entry 1 types from 0.
        tap("add.clear")
        XCTAssertEqual(rupiah(amount), 0)
        let scrollView = sheetScrollView()
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        scrollUntilVisible(app.buttons["add.tile.Kado"], in: scrollView)
        fling(scrollView, toward: .below) // past any remaining bottom padding
        snapshot(variant, 5, "add-scrolled-bottom")

        // 06 · Note focused, keyboard up, a short note typed.
        let note = app.textFields["add.note"]
        scrollUntilVisible(note, in: scrollView, notLaidOutLies: .above)
        note.tap()
        let keyboard = app.keyboards.firstMatch
        if !keyboard.waitForExistence(timeout: 5) {
            XCTContext.runActivity(named: "No software keyboard: the simulator may have a hardware keyboard connected") { _ in }
        }
        note.typeText("Nasi padang")
        snapshot(variant, 6, "add-note-keyboard")

        // Entry 1: Makan Rp25.000 with the note (Kebutuhan). Return ends editing; tapping the amount brings
        // the keypad back.
        note.typeText("\n")
        if keyboard.exists { _ = keyboard.waitForNonExistence(timeout: 5) }
        save(keys: ["2", "5", "000"], amount: 25_000, into: "Makan")

        // Entry 2: Kopi Rp18.000 (Keinginan).
        tap("history.add")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        save(keys: ["1", "8", "000"], amount: 18_000, into: "Kopi")

        // Entry 3: Gaji Rp8.500.000 (Pemasukan).
        tap("history.add")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        scrollUntilVisible(app.segmentedControls["add.kind"], in: sheetScrollView(), notLaidOutLies: .above)
        app.buttons["Pemasukan"].firstMatch.tap()
        save(keys: ["8", "5", "0", "0", "000"], amount: 8_500_000, into: "Gaji")

        // 07 · Riwayat with the three rows, newest (Gaji) first. Where they don't all fit (AX5), also
        // 07b · the list scrolled to the bottom, so the noted Makan row is reviewed too.
        // At AX5 the month and day headers fill the first screen, so the rows start below it and the
        // list hasn't built them yet: drag slowly until the newest row is in view.
        let gajiRow = transactionRow(containing: "Gaji")
        if !gajiRow.waitForExistence(timeout: 5) { revealRow(gajiRow) }
        XCTAssertTrue(gajiRow.exists, "the Gaji row is in the list")
        snapshot(variant, 7, "month-rows")
        let makanRow = transactionRow(containing: "Makan")
        if !makanRow.exists || !makanRow.isHittable {
            let list = app.collectionViews.firstMatch
            for _ in 0..<6 where !(makanRow.exists && makanRow.isHittable) { list.swipeUp() }
            XCTAssertTrue(makanRow.exists, "the third row is in the list")
            snapshot(variant, 7, "month-rows-bottom", suffix: "b")
            for _ in 0..<6 where !(gajiRow.exists && gajiRow.isHittable) { list.swipeDown() }
        }

        // 08 · Edit sheet from the swipe action ("Ubah"): prefilled, Kopi named under the amount (D-047).
        // Below XX Large text the grid also scrolls the highlighted tile into view; from there up the sheet
        // opens at the top, so the amount stays in view and the label tells what is selected. Editing opens
        // without the keypad (D-067).
        let kopiRow = transactionRow(containing: "Kopi")
        revealRow(kopiRow)
        XCTAssertTrue(kopiRow.exists, "the Kopi row is in the list")
        swipeAction(on: kopiRow, identifier: "transaction.row.edit", label: "Ubah")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        let selected = app.staticTexts["add.selected"]
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("Kopi"), "the label under the amount names Kopi: \(selected.label)")
        if sheetScrolls() {
            XCTAssertTrue(amount.isHittable, "the scrolling layout opens at the top, with the amount in view")
        } else {
            let kopi = app.buttons["add.tile.Kopi"]
            XCTAssertTrue(kopi.waitForExistence(timeout: 5))
            XCTAssertTrue(kopi.isSelected && kopi.isHittable, "the highlighted Kopi tile is in view without scrolling")
        }
        snapshot(variant, 8, "edit-opened")
        tap("add.cancel")
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))

        // 09 · Delete confirmation from the swipe action ("Hapus"): an alert with Hapus and Batal, never a popover.
        swipeAction(on: transactionRow(containing: "Kopi"), identifier: "transaction.row.delete", label: "Hapus")
        XCTAssertTrue(app.buttons.matching(identifier: "transaction.delete.confirm").firstMatch.waitForExistence(timeout: 5))
        let cancel = app.buttons["Batal"].firstMatch
        XCTAssertTrue(cancel.exists, "the delete dialog has a Batal button, so it isn't a popover")
        snapshot(variant, 9, "delete-dialog")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))

        // 10 · Home with the three entries: the hero's total and group rows, the columns with totals.
        // 10b · scrolled to the last card where it isn't in view (large text).
        app.tabBars.buttons["Beranda"].tap()
        XCTAssertTrue(element("home.hero").waitForExistence(timeout: 10))
        snapshot(variant, 10, "home-data")
        if scrollHome(toReveal: card("Hiburan")) {
            snapshot(variant, 10, "home-data-cards", suffix: "b")
        }
        scrollHome(toReveal: element("home.managePins"), direction: .above)

        // 11 · Quick add from the Kopi card: the sheet opens with Kopi preselected and named (D-044, D-047).
        scrollHome(toReveal: card("Kopi"))
        card("Kopi").tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("Kopi"), "quick add names Kopi: \(selected.label)")
        snapshot(variant, 11, "home-quick-add")
        tap("add.cancel")
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))

        // 12 · Atur: Kebutuhan, Keinginan and Pemasukan sections, pinned rows on top with reorder handles
        // and a count against the section's limit (D-068).
        scrollHome(toReveal: element("home.managePins"), direction: .above)
        tap("home.managePins")
        XCTAssertTrue(element("pins.header.kebutuhan").waitForExistence(timeout: 5))
        snapshot(variant, 12, "atur-sheet")

        // 12b · A 7th Kebutuhan pin refused: the toggle stays off and the note shows on glass (D-068).
        for name in ["Dapur", "Gas", "Listrik", "Air"] { flipPin(name) }
        XCTAssertTrue(element("pins.limitNote").waitForExistence(timeout: 3))
        snapshot(variant, 12, "atur-limit-note", suffix: "b")
        tap("pins.done")
        XCTAssertTrue(element("pins.list").waitForNonExistence(timeout: 5))

        // 13 · Relaunched with sample transactions (this and last month) and budgets: Home's top with the
        // hero's budget rows, 13c · the cards with a budget bar (Kopi under, Jajan over, said plainly),
        // 13d · the last card where it isn't in view yet.
        app.terminate()
        launch(extraArguments + ["-debugSample", "full"])
        XCTAssertTrue(element("home.hero").waitForExistence(timeout: 10))
        snapshot(variant, 13, "home-budgets")
        scrollHome(toReveal: card("Jajan"))
        snapshot(variant, 13, "home-budgets-cards", suffix: "c")
        if scrollHome(toReveal: card("Hiburan")) {
            snapshot(variant, 13, "home-budgets-bottom", suffix: "d")
        }

        // 14 · Long-press menu on a card: Lihat detail · Ubah · Lepas pin (D-012, D-051, D-062).
        card("Hiburan").press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["home.card.unpin"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.card.detail"].firstMatch.exists)
        XCTAssertTrue(app.buttons["home.card.edit"].firstMatch.exists)
        snapshot(variant, 14, "home-card-menu")

        // 15 · Lihat detail: Hiburan this month, nothing logged yet, lower than last month (said plainly).
        app.buttons["home.card.detail"].firstMatch.tap()
        XCTAssertTrue(element("detail.empty").waitForExistence(timeout: 5))
        snapshot(variant, 15, "card-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(card("Hiburan").waitForExistence(timeout: 5))

        try analysisTour(variant: variant)
        try historyTour(variant: variant)
        try recapTour(variant: variant)
        try settingsTour(variant: variant)
        try introductionTour(variant: variant, extraArguments: extraArguments)
        try storeErrorTour(variant: variant, extraArguments: extraArguments)
    }

    /// Shots 33–33c: the introduction's three pages (D-063), on a fresh throwaway store.
    @MainActor
    private func introductionTour(variant: String, extraArguments: [String]) throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(id)", "-AppleLocale", "id_ID", "-showOnboarding"] + extraArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["onboarding.title.1"].waitForExistence(timeout: 10))
        snapshot(variant, 33, "onboarding-question")
        tap("onboarding.next")
        XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 5))
        snapshot(variant, 33, "onboarding-cards", suffix: "b")
        tap("onboarding.next")
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 5))
        snapshot(variant, 33, "onboarding-groups", suffix: "c")
        tap("onboarding.start")
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 5))
    }

    /// Shot 34: the store error screen (D-063) with both things to save; 34b its bottom where it doesn't fit.
    @MainActor
    private func storeErrorTour(variant: String, extraArguments: [String]) throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(id)", "-AppleLocale", "id_ID", "-simulateStoreError", "exports"] + extraArguments
        app.launch()
        XCTAssertTrue(element("storeError.title").waitForExistence(timeout: 10))
        snapshot(variant, 34, "store-error")
        let code = element("storeError.code")
        if !(code.exists && code.isHittable) {
            let scroll = app.scrollViews.firstMatch
            for _ in 0..<8 where !(code.exists && code.isHittable) { scroll.swipeUp() }
            snapshot(variant, 34, "store-error-bottom", suffix: "b")
        }
    }

    /// Shots 16–20: the Analisis tab with the `full` sample (this month, last month and four before).
    @MainActor
    private func analysisTour(variant: String) throws {
        // 16 · The top: month stepper, Rincian filter, "paling banyak di", the donut.
        // 16b · The top 5 ranked rows (Kopi under its budget, Jajan over it).
        // 16c · Lihat semua and the income line under Rincian (D-070); 16d · the full breakdown it opens.
        app.tabBars.buttons["Analisis"].tap()
        XCTAssertTrue(element("analysis.donut").waitForExistence(timeout: 10))
        snapshot(variant, 16, "analysis-data")
        scrollPage(toReveal: element("analysis.row.Jajan"), in: "analysis.scroll")
        snapshot(variant, 16, "analysis-ranked", suffix: "b")
        scrollPage(toReveal: element("analysis.income"), in: "analysis.scroll")
        snapshot(variant, 16, "analysis-income", suffix: "c")
        scrollPage(toReveal: element("analysis.seeAll"), in: "analysis.scroll", direction: .above)
        element("analysis.seeAll").tap()
        XCTAssertTrue(app.navigationBars["Rincian"].waitForExistence(timeout: 5))
        scrollPage(toReveal: element("analysis.row.Galon"), in: "breakdown.scroll")
        snapshot(variant, 16, "analysis-breakdown-all", suffix: "d")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("analysis.donut").waitForExistence(timeout: 5))

        // 17 · Keinginan only: the donut, the list and the daily bars follow the filter.
        scrollPage(toReveal: element("analysis.filter.keinginan"), in: "analysis.scroll", direction: .above)
        element("analysis.filter.keinginan").tap()
        XCTAssertTrue(element("analysis.row.Makan").waitForNonExistence(timeout: 5))
        scrollPage(toReveal: element("analysis.filter.keinginan"), in: "analysis.scroll", direction: .above)
        snapshot(variant, 17, "analysis-filtered")
        element("analysis.filter.all").tap()
        XCTAssertTrue(element("analysis.row.Makan").waitForExistence(timeout: 5))

        // 18 · Tren on Mingguan; 18b · the six months of pengeluaran and pemasukan, this month highlighted.
        scrollPage(toReveal: element("analysis.granularity.weekly"), in: "analysis.scroll")
        element("analysis.granularity.weekly").tap()
        XCTAssertTrue(element("analysis.granularity.weekly").isSelected)
        scrollPage(toReveal: element("analysis.trend.chart"), in: "analysis.scroll")
        snapshot(variant, 18, "analysis-weekly")
        scrollPage(toReveal: element("analysis.series.chart"), in: "analysis.scroll")
        snapshot(variant, 18, "analysis-six-months", suffix: "b")

        // 19 · A ranked row's detail: Kopi with its budget and the comparison with last month.
        scrollPage(toReveal: element("analysis.row.Kopi"), in: "analysis.scroll", direction: .above)
        element("analysis.row.Kopi").tap()
        XCTAssertTrue(element("detail.budget").waitForExistence(timeout: 5))
        snapshot(variant, 19, "analysis-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("analysis.donut").waitForExistence(timeout: 5))

        // 20 · Six months back nothing was logged: the calm empty note, reached with the stepper's ‹.
        let stepper = element("analysis.month")
        scrollPage(toReveal: stepper, in: "analysis.scroll", direction: .above)
        for _ in 0..<6 {
            let before = stepper.value as? String ?? ""
            stepper.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", before), object: stepper)
            XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 5), .completed, "the stepper moved back from \(before)")
        }
        XCTAssertTrue(element("analysis.empty").waitForExistence(timeout: 5))
        snapshot(variant, 20, "analysis-empty")
    }

    /// Shots 21–23: Riwayat as History with the `full` sample (D-053).
    @MainActor
    private func historyTour(variant: String) throws {
        // 21 · The top of the long list: this month's header, sticky day headers, rows.
        app.tabBars.buttons["Riwayat"].tap()
        let list = element("history.list")
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        XCTAssertTrue(element("history.month").waitForExistence(timeout: 5))
        snapshot(variant, 21, "history-list")

        // 21b · Scrolled back: older months loaded as the list scrolls, a day header pinned at the top.
        for _ in 0..<4 { list.swipeUp() }
        snapshot(variant, 21, "history-older", suffix: "b")
        for _ in 0..<12 { list.swipeDown() }

        // 22 · Search by amount: "18.000" finds the Rp18.000 entries, months back, grouped by day.
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("18.000")
        XCTAssertTrue(transactionRow(containing: "Kopi tubruk").waitForExistence(timeout: 10))
        snapshot(variant, 22, "history-search")

        // 23 · A search with no match: the calm no-results note.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "sepeda")
        XCTAssertTrue(element("history.noResults").waitForExistence(timeout: 10))
        snapshot(variant, 23, "history-no-results")

        // End the search: its keyboard covers the tab bar, so the next tab tap would land on a key.
        // The button reads "Batalkan" on iOS 18 and "Tutup" on iOS 26.
        let endSearch = app.navigationBars.buttons.matching(NSPredicate(format: "label IN %@", ["Tutup", "Batalkan", "Batal"])).firstMatch
        XCTAssertTrue(endSearch.waitForExistence(timeout: 5), "the search field's cancel button")
        endSearch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "the keyboard goes away")
    }

    /// Shots 24–25: Rekap tahunan (D-059) with the `full` sample, whose months before the raw window were
    /// rolled up on launch.
    @MainActor
    private func recapTour(variant: String) throws {
        // 24 · This year, year to date: the totals and the split; 24b · the twelve months; 24c · the ranking.
        app.tabBars.buttons["Analisis"].tap()
        let link = element("analysis.recap")
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        scrollPage(toReveal: link, in: "analysis.scroll")
        link.tap()
        let year = element("recap.year")
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        XCTAssertTrue(element("recap.ytd").exists)
        snapshot(variant, 24, "recap-this-year")
        scrollPage(toReveal: element("recap.chart"), in: "recap.scroll")
        snapshot(variant, 24, "recap-months", suffix: "b")
        scrollPage(toReveal: element("recap.row.Makan"), in: "recap.scroll")
        snapshot(variant, 24, "recap-ranking", suffix: "c")

        // 25 · Last year, completed: rollups for the purged months plus the raw ones; 25b · its ranking,
        // with "Langganan", a gone subcategory named by its snapshot (14 months back, so last year from
        // March on; in January and February the bottom of the ranking is shown instead).
        scrollPage(toReveal: year, in: "recap.scroll", direction: .above)
        let before = year.value as? String ?? ""
        year.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", before), object: year)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 5), .completed, "the stepper moved back from \(before)")
        XCTAssertTrue(element("recap.ytd").waitForNonExistence(timeout: 5))
        snapshot(variant, 25, "recap-last-year")
        let langganan = element("recap.row.Langganan")
        scrollPage(toReveal: langganan.exists ? langganan : element("recap.row.Makan"), in: "recap.scroll")
        snapshot(variant, 25, "recap-last-year-ranking", suffix: "b")
    }

    /// Shot 26: Pengaturan, top to bottom Anggaran (the `full` sample's budgets), Subkategori, Cadangan & Ekspor
    /// and Tentang. The throwaway store has no backup folder, so the folder row says so and "Cadangkan sekarang"
    /// is absent (D-060). Then the Phase 10 shots, 27–32.
    @MainActor
    private func settingsTour(variant: String) throws {
        app.tabBars.buttons["Pengaturan"].tap()
        XCTAssertTrue(element("settings.budget.kebutuhan").waitForExistence(timeout: 10))
        snapshot(variant, 26, "settings")
        let version = element("settings.version")
        if !(version.exists && version.isHittable) {
            let form = element("settings.form")
            for _ in 0..<8 where !(version.exists && version.isHittable) { form.swipeUp() }
            XCTAssertTrue(version.exists, "Tentang is the last section")
            snapshot(variant, 26, "settings-bottom", suffix: "b")
        }
        try budgetTour(variant: variant)
        try subcategoryTour(variant: variant)
    }

    /// Shot 27: the Kebutuhan budget sheet with the sample's Rp3.000.000, the keypad and Hapus anggaran. Cancelled.
    @MainActor
    private func budgetTour(variant: String) throws {
        let row = element("settings.budget.kebutuhan")
        scrollPage(toReveal: row, in: "settings.form", direction: .above)
        row.tap()
        XCTAssertTrue(app.buttons["budget.key.1"].waitForExistence(timeout: 5))
        snapshot(variant, 27, "budget-sheet")
        tap("budget.cancel")
        XCTAssertTrue(app.buttons["budget.cancel"].waitForNonExistence(timeout: 5))
    }

    /// Shots 28–32: Kelola subkategori, Edit mode, the editor (add and Ubah), the hide confirmation, and
    /// Ubah from a Home card. Nothing is saved, so the store stays as the sample made it.
    @MainActor
    private func subcategoryTour(variant: String) throws {
        // Just below the Anggaran rows, where the budget tour left the form.
        let link = element("settings.subcategories")
        scrollPage(toReveal: link, in: "settings.form", direction: .below)
        link.tap()
        XCTAssertTrue(element("subcategories.list").waitForExistence(timeout: 5))
        snapshot(variant, 28, "subcategories")

        // 28b · Pemasukan: one flat list.
        app.buttons["Pemasukan"].firstMatch.tap()
        XCTAssertTrue(element("subcategories.row.Gaji").waitForExistence(timeout: 5))
        snapshot(variant, 28, "subcategories-income", suffix: "b")
        app.buttons["Pengeluaran"].firstMatch.tap()
        XCTAssertTrue(element("subcategories.row.Makan").waitForExistence(timeout: 5))

        // 29 · Edit mode: drag handles, within each section.
        tap("subcategories.edit")
        snapshot(variant, 29, "subcategories-edit")
        tap("subcategories.edit")

        // 30 · Adding: one emoji, and a name that breaks the one-word rule, with its reason; 30b valid.
        tap("subcategories.add")
        let emoji = element("editor.emoji")
        XCTAssertTrue(emoji.waitForExistence(timeout: 5))
        emoji.tap()
        emoji.typeText("🍜")
        let name = element("editor.name")
        name.tap()
        name.typeText("Bakso goreng")
        XCTAssertTrue(element("editor.nameProblem").waitForExistence(timeout: 5))
        snapshot(variant, 30, "editor-add-invalid")
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        XCTAssertTrue(element("editor.nameProblem").waitForNonExistence(timeout: 5))
        name.typeText(XCUIKeyboardKey.return.rawValue)
        snapshot(variant, 30, "editor-add-valid", suffix: "b")
        tap("editor.cancel")
        XCTAssertTrue(app.buttons["editor.cancel"].waitForNonExistence(timeout: 5))

        // 31 · Ubah on Kopi, which has history and a budget: the delete button says it will be hidden.
        let kopi = element("subcategories.row.Kopi")
        scrollPage(toReveal: kopi, in: "subcategories.list")
        kopi.tap()
        XCTAssertTrue(element("editor.name").waitForExistence(timeout: 5))
        snapshot(variant, 31, "editor-edit")
        let remove = app.buttons["editor.remove"].firstMatch
        let form = element("editor.form")
        for _ in 0..<6 where !(remove.exists && remove.isHittable) { form.swipeUp() }
        remove.tap()
        // 31b · The confirmation: hidden, not deleted (D-006); history stays and the card leaves Home (D-049).
        XCTAssertTrue(app.buttons["editor.remove.confirm"].firstMatch.waitForExistence(timeout: 5))
        snapshot(variant, 31, "editor-hide-confirmation", suffix: "b")
        app.alerts.buttons["Batal"].firstMatch.tap()
        tap("editor.cancel")
        XCTAssertTrue(app.buttons["editor.cancel"].waitForNonExistence(timeout: 5))

        // 32 · Ubah from a Home card's menu opens the same editor.
        app.tabBars.buttons["Beranda"].tap()
        scrollHome(toReveal: card("Makan"), direction: .above)
        card("Makan").press(forDuration: 1.2)
        tap("home.card.edit")
        XCTAssertTrue(element("editor.name").waitForExistence(timeout: 5))
        snapshot(variant, 32, "editor-from-card")
        tap("editor.cancel")
    }

    /// Throwaway seeded store, Indonesian language and region (as in `KemanayaUITests`); the app opens on Beranda.
    @MainActor
    private func launch(_ extraArguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(id)", "-AppleLocale", "id_ID"] + extraArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 10))
    }

    // MARK: - Screenshots

    /// Lets transitions finish, then attaches a full-screen screenshot named `<variant>-<NN>-<state>`.
    @MainActor
    private func snapshot(_ variant: String, _ number: Int, _ state: String, suffix: String = "") {
        settle()
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(variant)-\(String(format: "%02d", number))\(suffix)-\(state)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A short pause for sheet, keyboard and swipe animations, which XCUITest's idle wait doesn't always cover.
    private func settle(_ seconds: TimeInterval = 0.8) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    // MARK: - Helpers

    /// The first element with `identifier`. SwiftUI sometimes puts it on a wrapper and on the control too.
    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Taps the button with `identifier`.
    @MainActor
    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = app.buttons[identifier]
        XCTAssertTrue(target.waitForExistence(timeout: 5), "missing \(identifier)", file: file, line: line)
        target.tap()
    }

    /// Presses keypad keys (`"0"`…`"9"`, `"000"`). The keypad is the amount's keyboard (D-067): when it
    /// isn't up (a drag or the note dismissed it), the amount is tapped first to bring it back.
    @MainActor
    private func press(_ keys: [String]) {
        if !app.buttons["add.key.1"].exists {
            let amount = app.staticTexts["add.amount"]
            if sheetScrolls() { scrollUntilVisible(amount, in: sheetScrollView(), notLaidOutLies: .above) }
            amount.tap()
        }
        for key in keys {
            let target = app.buttons["add.key.\(key)"]
            XCTAssertTrue(target.waitForExistence(timeout: 5), "missing add.key.\(key)")
            target.tap()
        }
    }

    /// Types an amount, selects a tile and saves with Simpan (D-067). A tile tap only selects, so a scroll
    /// gesture that fires a tile can't save; the tile is tapped once more after scrolling to it.
    @MainActor
    private func save(keys: [String], amount expected: Int64, into name: String) {
        let tile = app.buttons["add.tile.\(name)"]
        let amount = app.staticTexts["add.amount"]
        press(keys)
        XCTAssertEqual(rupiah(amount), expected)
        scrollUntilVisible(tile, in: sheetScrollView())
        tile.tap()
        XCTAssertTrue(tile.isSelected, "\(name) is selected")
        tap("add.save")
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "Simpan saves into \(name) and dismisses")
    }

    /// True from XX Large text, where the whole sheet scrolls, amount included; below that the kind
    /// switch and amount are fixed above the scrolling grid.
    @MainActor
    private func sheetScrolls() -> Bool {
        sheetScrollView().staticTexts["add.amount"].exists
    }

    @MainActor
    private func card(_ name: String) -> XCUIElement {
        app.buttons["home.card.\(name)"]
    }

    /// Scrolls Home until `target` is fully hittable. Flings start in the 16 pt side margin, never on a card
    /// (a card tap opens the add sheet), and each waits for the content to settle.
    /// - Returns: whether it had to scroll.
    @discardableResult
    @MainActor
    private func scrollHome(toReveal target: XCUIElement, direction: Direction = .below, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        scrollPage(toReveal: target, in: "home.scroll", direction: direction, file: file, line: line)
    }

    /// Scrolls the page scroll view `identifier` (Home, Analisis) until `target` is fully hittable, as
    /// ``scrollHome(toReveal:direction:file:line:)`` describes.
    @discardableResult
    @MainActor
    private func scrollPage(toReveal target: XCUIElement, in identifier: String, direction: Direction = .below, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let scroll = element(identifier)
        XCTAssertTrue(scroll.waitForExistence(timeout: 5), file: file, line: line)
        var scrolled = false
        for _ in 0..<20 {
            // Fully on screen: below the navigation bar and above the tab bar.
            let navigationBar = app.navigationBars.firstMatch
            let tabBar = app.tabBars.firstMatch
            let top = max(scroll.frame.minY, navigationBar.exists ? navigationBar.frame.maxY : 0)
            let bottom = min(scroll.frame.maxY, tabBar.exists ? tabBar.frame.minY : .greatestFiniteMagnitude)
            let isHittable = target.exists && target.isHittable
            // Laid out but off screen (a page's VStack builds everything): nudge toward it from whichever
            // side it is on, so a fling can't carry the page past it and keep going the wrong way (AX5).
            let frame = target.exists ? target.frame : .null
            let isOffScreen = !frame.isNull && (frame.maxY <= top || frame.minY >= bottom)
            if isHittable || isOffScreen {
                if isHittable {
                    if frame.minY >= top, frame.maxY <= bottom { return scrolled }
                    // A target taller than the gap can't fit; its top in view is enough.
                    if frame.height > bottom - top, frame.minY >= top, frame.minY < bottom - 40 { return scrolled }
                }
                if frame.minY < top {
                    nudge(scroll, by: top - frame.minY + 16)
                } else {
                    nudge(scroll, by: -min(frame.maxY - bottom + 16, frame.minY - top - 16))
                }
            } else {
                fling(scroll, toward: direction)
            }
            scrolled = true
            waitUntilStill(target.exists ? target : scroll)
        }
        XCTAssertTrue(target.exists && target.isHittable, "could not reveal \(target)", file: file, line: line)
        return scrolled
    }

    /// Scrolls the Atur list to `name`'s row and flips its switch control (not the label).
    @MainActor
    private func flipPin(_ name: String) {
        let row = app.switches["pins.toggle.\(name)"]
        let list = element("pins.list")
        // The switch control itself must be inside the list: a row can be "hittable" while its switch is
        // still below the list's edge (AX5 on iOS 18).
        let control = { row.switches.firstMatch.exists ? row.switches.firstMatch : row }
        let isReachable = { row.exists && list.frame.insetBy(dx: 0, dy: 8).contains(control().frame) }
        for _ in 0..<10 where !isReachable() {
            if row.exists, control().frame.minY < list.frame.minY { list.swipeDown(velocity: .slow) } else { list.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(isReachable(), "could not reach \(name)")
        if row.switches.firstMatch.exists {
            row.switches.firstMatch.tap()
        } else {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
    }

    /// A measured drag in Home's side margin: positive `offset` moves the content down.
    @MainActor
    private func nudge(_ scroll: XCUIElement, by offset: CGFloat) {
        let frame = scroll.frame
        let limit = frame.height * 0.6
        let distance = (offset < 0 ? -1 : 1) * min(limit, max(40, abs(offset)))
        let start = scroll.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 6, dy: frame.height / 2 - distance / 2))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)), withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// The sheet's scroll view: the middle part below XX Large text, the whole sheet from there up.
    @MainActor
    private func sheetScrollView() -> XCUIElement {
        app.scrollViews["add.scroll"]
    }

    /// Where to look for an element the lazy grid hasn't built yet.
    private enum Direction { case above, below }

    /// Scrolls `scrollView` until `target`'s centre (where a tap lands) is inside its visible part: toward
    /// it when it is laid out off screen, and toward `notLaidOutLies` when it isn't laid out at all (the lazy
    /// grid builds tiles near the viewport). An element outside the scroll view (the keypad and the fixed kind
    /// switch below XX Large text) only needs to be hittable.
    ///
    /// Gestures, both learned on iOS 18: a slow drag that starts near a button can fire it, and a tap while
    /// content still moves lands on whatever slid under it. So after every gesture this waits for stillness.
    /// It uses measured drags in the side margin of the part no bar or keyboard covers, which can't
    /// overshoot a short grid and never start on a key; the sheet ignores a tile a drag fires (D-067). The
    /// first drag also dismisses the keyboard, so the visible part is measured again after each gesture.
    /// Each accessibility query snapshots the app's tree, and a flood of them crashed XCTest's in-app agent
    /// on the iOS 18.3 SE, so queries are kept few.
    @MainActor
    private func scrollUntilVisible(
        _ target: XCUIElement,
        in scrollView: XCUIElement,
        notLaidOutLies direction: Direction = .below,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var visible = visibleRect(of: scrollView).insetBy(dx: 0, dy: 12)
        var isInside: Bool?
        var hasScrolled = false
        for _ in 0..<30 {
            if hasScrolled {
                waitUntilStill(target.exists ? target : scrollView)
                visible = visibleRect(of: scrollView).insetBy(dx: 0, dy: 12)
                hasScrolled = false
            }
            guard target.exists else {
                fling(scrollView, toward: direction)
                hasScrolled = true
                continue
            }
            if isInside == nil {
                isInside = scrollView.descendants(matching: target.elementType).matching(identifier: target.identifier).firstMatch.exists
            }
            let frame = target.frame
            if isInside == false, target.isHittable { return }
            if isInside == true, visible.contains(CGPoint(x: frame.midX, y: frame.midY)), target.isHittable { return }
            drag(scrollView, within: visible, by: visible.midY - frame.midY)
            hasScrolled = true
        }
        XCTAssertTrue(target.exists && target.isHittable, "could not scroll to \(target)", file: file, line: line)
    }

    /// Scrolls the content by about `offset` points (positive moves it down), at most 40 % of the visible
    /// height per call. A press-drag-hold has no fling, so it can't overshoot a small viewport (the SE's
    /// standard layout leaves the grid about 220 pt), as swipes do. It starts in the sheet's 16 pt side
    /// margin: on iOS 18 a slow drag that starts on a tile fires the tile's button (the sheet ignores it).
    @MainActor
    private func drag(_ scrollView: XCUIElement, within visible: CGRect, by offset: CGFloat) {
        let limit = visible.height * 0.4
        // At least 40 pt, so the drag is never mistaken for a tap on a tile (which would select it).
        let distance = (offset < 0 ? -1 : 1) * min(limit, max(40, abs(offset)))
        let frame = scrollView.frame
        let origin = scrollView.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: 6, dy: visible.midY - frame.minY - distance / 2))
        let end = start.withOffset(CGVector(dx: 0, dy: distance))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// Waits until `element` stops moving (deceleration, or the bounce back from an edge). A tap while
    /// content still moves lands on whatever is under the old hit point: on iOS 18 that typed a wrong key
    /// or saved into a wrong tile.
    @MainActor
    private func waitUntilStill(_ element: XCUIElement) {
        var last = element.frame
        for _ in 0..<12 {
            settle(0.15)
            let now = element.frame
            if now == last { return }
            last = now
        }
    }

    /// A quick scroll toward `direction`, for content the lazy grid hasn't built yet. Like ``drag(_:within:by:)``
    /// it starts in the side margin, never on a tile.
    @MainActor
    private func fling(_ scrollView: XCUIElement, toward direction: Direction) {
        let visible = visibleRect(of: scrollView)
        let distance = visible.height * 0.6 * (direction == .below ? -1 : 1)
        let origin = scrollView.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: 6, dy: visible.midY - scrollView.frame.minY - distance / 2))
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)), withVelocity: .fast, thenHoldForDuration: 0)
    }

    /// The part of the sheet's scroll view not covered by its navigation bar (whose Batal button marks it)
    /// or by a keyboard: the scroll view runs on under the keypad and the system keyboard (D-067), and a
    /// gesture that starts there would press a key.
    @MainActor
    private func visibleRect(of scrollView: XCUIElement) -> CGRect {
        var rect = scrollView.frame
        let cancel = app.buttons["add.cancel"]
        if cancel.exists {
            let barBottom = cancel.frame.maxY + 8
            if barBottom > rect.minY {
                rect.size.height -= barBottom - rect.minY
                rect.origin.y = barBottom
            }
        }
        let keypadKey = app.buttons["add.key.1"]
        let keyboard = app.keyboards.firstMatch
        let keyboardTop: CGFloat? = keypadKey.exists ? keypadKey.frame.minY - 16 : (keyboard.exists ? keyboard.frame.minY : nil)
        if let keyboardTop, keyboardTop < rect.maxY {
            rect.size.height = max(0, keyboardTop - rect.minY)
        }
        return rect
    }

    @MainActor
    private func transactionRow(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'transaction.row' AND label CONTAINS %@", text))
            .firstMatch
    }

    /// Drags Riwayat's list slowly, without momentum, until `row` is in view. At AX5 a row can start below
    /// the first screen, where the list hasn't built it yet.
    /// The row must clear the tab bar too: on iOS 26 it floats over the list, and a swipe on a row under it
    /// lands on the bar.
    @MainActor
    private func revealRow(_ row: XCUIElement, toward direction: Direction = .below) {
        let list = element("history.list")
        let navigationBar = app.navigationBars.firstMatch
        let tabBar = app.tabBars.firstMatch
        for _ in 0..<10 {
            let top = max(list.frame.minY, navigationBar.exists ? navigationBar.frame.maxY : 0)
            let bottom = min(list.frame.maxY, tabBar.exists ? tabBar.frame.minY : .greatestFiniteMagnitude)
            if row.exists, row.isHittable {
                let frame = row.frame
                if frame.minY >= top, frame.maxY <= bottom { return }
                nudge(list, by: frame.maxY > bottom ? -(frame.maxY - bottom + 16) : top - frame.minY + 16)
            } else {
                nudge(list, by: (direction == .below ? -1 : 1) * list.frame.height * 0.4)
            }
            waitUntilStill(list)
        }
    }

    /// Swipes the row open and taps one of its actions, by identifier when the swipe button exposes it.
    @MainActor
    private func swipeAction(on row: XCUIElement, identifier: String, label: String) {
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let byIdentifier = app.buttons.matching(identifier: identifier).firstMatch
        if byIdentifier.waitForExistence(timeout: 2) {
            byIdentifier.tap()
        } else {
            app.buttons[label].firstMatch.tap()
        }
    }

    /// The whole rupiah an amount element reads to VoiceOver, e.g. "25.000 rupiah" → 25000.
    @MainActor
    private func rupiah(_ element: XCUIElement) -> Int64? {
        Int64(element.label.filter(\.isNumber))
    }
}
