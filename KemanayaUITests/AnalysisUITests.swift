import XCTest

/// Analisis (D-051, D-070): the empty month, the ranked list with the group filter, the month stepper, the
/// Harian / Mingguan switch, the top 5 with **Lihat semua** and the income line, drilling into a
/// subcategory's detail (swipe = Ubah or Hapus, D-079), **Lihat detail** from a pinned card, and the
/// yearly recap (D-059). Sample data comes from the DEBUG `-debugSample` argument.
final class AnalysisUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A throwaway seeded store with Indonesian language and region; `extraArguments` e.g. `-debugSample full`.
    @MainActor
    private func launch(_ extraArguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(id)", "-AppleLocale", "id_ID"] + extraArguments
        app.launch()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 10), "the app opens on Beranda")
    }

    @MainActor
    private func openAnalisis() {
        app.tabBars.buttons["Analisis"].tap()
        XCTAssertTrue(app.navigationBars["Analisis"].waitForExistence(timeout: 5))
    }

    /// A fresh install: the calm empty note, the stepper on this month, and no month after it (D-044).
    @MainActor
    func testEmptyMonthShowsTheNoteAndTheStepperStopsAtThisMonth() throws {
        launch()
        openAnalisis()
        XCTAssertTrue(element("analysis.empty").waitForExistence(timeout: 5))
        XCTAssertFalse(element("analysis.filter.all").exists, "no filter without spending")
        XCTAssertFalse(element("analysis.donut").exists)
        XCTAssertTrue(element("analysis.series.empty").exists, "the six months are empty too")
        XCTAssertFalse(element("analysis.income").exists, "no spending and no income: no income line")
        XCTAssertFalse(element("analysis.seeAll").exists)

        let thisMonth = monthValue()
        tapStepper(.next)
        assertMonthStays(thisMonth, "› is disabled on the current month")
        tapStepper(.previous)
        waitForMonth(notEqualTo: thisMonth)
        tapStepper(.next)
        waitForMonth(equalTo: thisMonth)
    }

    /// With sample transactions: ranked rows, the group filter, Mingguan, and the stepper (Hiburan was
    /// spent only last month).
    @MainActor
    func testFilterStepperAndGranularity() throws {
        launch(["-debugSample", "transactions"])
        openAnalisis()
        XCTAssertTrue(element("analysis.donut").waitForExistence(timeout: 5))
        XCTAssertTrue(row("Makan").exists)
        XCTAssertTrue(row("Kopi").exists)
        XCTAssertFalse(row("Gaji").exists, "income is never ranked")
        XCTAssertFalse(row("Hiburan").exists, "Hiburan has nothing this month")
        XCTAssertTrue(element("analysis.largest").label.contains("Makan"), "Makan is the largest: \(element("analysis.largest").label)")

        tap("analysis.filter.keinginan")
        XCTAssertTrue(row("Makan").waitForNonExistence(timeout: 5), "Keinginan hides Kebutuhan")
        XCTAssertTrue(row("Kopi").exists)
        XCTAssertTrue(element("analysis.filter.keinginan").isSelected)
        tap("analysis.filter.kebutuhan")
        XCTAssertTrue(row("Kopi").waitForNonExistence(timeout: 5), "Kebutuhan hides Keinginan")
        XCTAssertTrue(row("Makan").exists)
        tap("analysis.filter.all")
        XCTAssertTrue(row("Kopi").waitForExistence(timeout: 5))

        reveal(element("analysis.granularity.weekly"))
        tap("analysis.granularity.weekly")
        XCTAssertTrue(element("analysis.granularity.weekly").isSelected)
        XCTAssertTrue(element("analysis.trend.chart").exists)
        XCTAssertTrue(element("analysis.series.chart").exists)

        reveal(element("analysis.month"), direction: .above)
        let thisMonth = monthValue()
        tapStepper(.previous)
        waitForMonth(notEqualTo: thisMonth)
        XCTAssertTrue(row("Hiburan").waitForExistence(timeout: 5), "last month had Hiburan")
        tapStepper(.next)
        waitForMonth(equalTo: thisMonth)
        XCTAssertTrue(row("Hiburan").waitForNonExistence(timeout: 5))
    }

    /// Rincian lists the top 5 and **Lihat semua** (D-070), which pushes every row with the same filter;
    /// the income line between Rincian and Tren counts all spending against the month's income.
    @MainActor
    func testTopFiveLihatSemuaAndTheIncomeLine() throws {
        launch(["-debugSample", "transactions"])
        openAnalisis()
        XCTAssertTrue(element("analysis.donut").waitForExistence(timeout: 5))
        // The sample's month ranks Makan, Listrik, Kopi, Jajan, Pulsa, then Ojol, Parkir, Galon.
        let top = ["Makan", "Listrik", "Kopi", "Jajan", "Pulsa"]
        let rest = ["Ojol", "Parkir", "Galon"]
        for name in top {
            XCTAssertTrue(row(name).exists, "\(name) is in the top 5")
        }
        for name in rest {
            XCTAssertFalse(row(name).exists, "\(name) is behind Lihat semua")
        }

        let seeAll = element("analysis.seeAll")
        reveal(seeAll)
        XCTAssertTrue(seeAll.exists, "more than 5 subcategories: Lihat semua")
        XCTAssertEqual(seeAll.value as? String, "8 kategori")
        let income = element("analysis.income")
        reveal(income)
        XCTAssertTrue(income.exists)
        let reading = digitsOnly(income.label)
        XCTAssertTrue(reading.contains("Pengeluaran 2310500 rupiah dari pemasukan 8500000 rupiah"), "every expense against Gaji: \(income.label)")
        XCTAssertGreaterThan(income.frame.minY, seeAll.frame.maxY, "the line sits under Rincian")
        reveal(element("analysis.granularity.daily"))
        XCTAssertLessThan(income.frame.maxY, element("analysis.granularity.daily").frame.minY, "and above Tren")

        // The filter doesn't change the line: it is all of the month's spending.
        reveal(element("analysis.filter.keinginan"), direction: .above)
        tap("analysis.filter.keinginan")
        XCTAssertTrue(row("Makan").waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("analysis.seeAll").exists, "two Keinginan rows: no Lihat semua")
        XCTAssertTrue(digitsOnly(element("analysis.income").label).contains("2310500"), "the line ignores the filter")
        tap("analysis.filter.all")
        XCTAssertTrue(row("Makan").waitForExistence(timeout: 5))

        reveal(seeAll)
        seeAll.tap()
        XCTAssertTrue(app.navigationBars["Rincian"].waitForExistence(timeout: 5), "Lihat semua pushes Rincian")
        XCTAssertTrue(element("breakdown.month").label.contains(monthTitle()), "the month: \(element("breakdown.month").label)")
        XCTAssertTrue(element("analysis.donut").exists, "the same donut")
        for name in top + rest {
            let target = row(name)
            reveal(target, in: "breakdown.scroll")
            XCTAssertTrue(target.exists, "\(name) is in the full list")
        }
        XCTAssertFalse(element("analysis.seeAll").exists, "the full list has no Lihat semua")

        // The filter here is Analisis's: Kebutuhan hides Kopi on both screens.
        reveal(element("analysis.filter.kebutuhan"), in: "breakdown.scroll", direction: .above)
        tap("analysis.filter.kebutuhan", in: "breakdown.scroll")
        XCTAssertTrue(row("Kopi").waitForNonExistence(timeout: 5))
        let galon = row("Galon")
        reveal(galon, in: "breakdown.scroll")
        galon.tap()
        XCTAssertTrue(element("detail.total").waitForExistence(timeout: 5), "a row opens the detail")
        XCTAssertTrue(app.navigationBars.staticTexts["💧 Galon"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Rincian"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Analisis"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("analysis.filter.kebutuhan").isSelected, "back on Analisis, Kebutuhan stays on")
        XCTAssertFalse(row("Kopi").exists)
        XCTAssertTrue(element("analysis.seeAll").exists, "six Kebutuhan rows: Lihat semua")
    }

    /// Ranked row → detail; swipe a transaction → Ubah (the edit sheet) or Hapus (the alert) (D-079).
    @MainActor
    func testRankedRowOpensTheDetailWithEditAndDelete() throws {
        launch(["-debugSample", "full"])
        openAnalisis()
        let kopi = row("Kopi")
        reveal(kopi)
        kopi.tap()
        XCTAssertTrue(element("detail.total").waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.staticTexts["☕ Kopi"].exists, "the detail is titled with the subcategory")
        XCTAssertTrue(digitsOnly(element("detail.total").label).contains("245000"), "this month's total: \(element("detail.total").label)")
        XCTAssertTrue(element("detail.budget").exists, "Kopi has a budget in the full sample")
        XCTAssertTrue(element("detail.comparison").exists)

        let transaction = element("detail.row")
        XCTAssertTrue(transaction.waitForExistence(timeout: 5))
        transaction.swipeLeft()
        let edit = app.buttons.matching(identifier: "transaction.row.edit").firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "swipe shows Ubah")
        edit.tap()
        let amount = app.staticTexts["add.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "Ubah opens the edit sheet")
        XCTAssertTrue(app.buttons["add.tile.Kopi"].isSelected, "the Kopi tile is highlighted")
        tap("add.cancel")
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))

        transaction.swipeLeft()
        let delete = app.buttons.matching(identifier: "transaction.row.delete").firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "swipe shows Hapus")
        delete.tap()
        let confirm = app.buttons.matching(identifier: "transaction.delete.confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "swipe Hapus asks first")
        confirm.tap()
        XCTAssertTrue(element("detail.empty").waitForExistence(timeout: 5), "the month's only Kopi entry is gone")
        XCTAssertTrue(element("detail.total").label.contains("0 transaksi"), "the total follows: \(element("detail.total").label)")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Analisis"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("Kopi").waitForNonExistence(timeout: 5), "Analisis follows the delete")
    }

    /// The card menu's Lihat detail (D-012, D-051) opens the same detail for the current month.
    @MainActor
    func testLihatDetailFromAPinnedCard() throws {
        launch(["-debugSample", "transactions"])
        let card = app.buttons["home.card.Jajan"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 1.2)
        let detail = app.buttons["home.card.detail"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "the menu offers Lihat detail")
        XCTAssertEqual(detail.label, "Lihat detail")
        XCTAssertTrue(app.buttons["home.card.unpin"].firstMatch.exists, "Lepas pin stays")
        detail.tap()
        XCTAssertTrue(element("detail.total").waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.staticTexts["🍿 Jajan"].exists)
        XCTAssertTrue(digitsOnly(element("detail.total").label).contains("186500"), "this month's Jajan: \(element("detail.total").label)")
        XCTAssertTrue(element("detail.comparison").label.contains("Sama dengan"), "Jajan matches last month: \(element("detail.comparison").label)")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5), "back on Beranda")
    }

    /// Rekap tahunan (D-059): the row at the end of Analisis opens this year, year to date; ‹ goes to last
    /// year, which the sample fills from rollups (purged on launch) and raw months, ranked; › comes back.
    @MainActor
    func testYearlyRecapOpensThisYearAndStepsBack() throws {
        launch(["-debugSample", "transactions"])
        openAnalisis()
        let link = element("analysis.recap")
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        reveal(link)
        link.tap()

        let year = element("recap.year")
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        let thisYear = String(Calendar(identifier: .gregorian).component(.year, from: .now))
        XCTAssertEqual(year.value as? String, "\(thisYear), sampai hari ini", "this year is year to date")
        XCTAssertTrue(element("recap.expenses").exists)
        XCTAssertTrue(element("recap.chart").exists, "the twelve months")

        year.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        let lastYear = String(Int(thisYear)! - 1)
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", lastYear), object: year)
        XCTAssertEqual(XCTWaiter().wait(for: [moved], timeout: 5), .completed, "‹ shows last year: \(year.value as? String ?? "")")
        XCTAssertFalse(element("recap.ytd").exists, "a completed year isn't year to date")
        XCTAssertTrue(element("recap.expenses").waitForExistence(timeout: 5))
        XCTAssertFalse(element("recap.empty").exists, "last year has rollups and raw months")
        XCTAssertTrue(element("recap.row.Makan").exists, "the ranked list")

        year.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let back = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", thisYear), object: year)
        XCTAssertEqual(XCTWaiter().wait(for: [back], timeout: 5), .completed, "› comes back to this year")
    }

    // MARK: - Helpers

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func row(_ name: String) -> XCUIElement {
        element("analysis.row.\(name)")
    }

    @MainActor
    private func tap(_ identifier: String, in scrollIdentifier: String = "analysis.scroll", file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "missing \(identifier)", file: file, line: line)
        reveal(target, in: scrollIdentifier)
        target.tap()
    }

    /// "November 2026", as the app writes this month in Indonesian.
    private func monthTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: .now)
    }

    private enum Arrow { case previous, next }

    /// The stepper is one adjustable element for VoiceOver, so its arrows are tapped by position.
    @MainActor
    private func tapStepper(_ arrow: Arrow) {
        let stepper = element("analysis.month")
        XCTAssertTrue(stepper.waitForExistence(timeout: 5))
        stepper.coordinate(withNormalizedOffset: CGVector(dx: arrow == .previous ? 0.05 : 0.95, dy: 0.5)).tap()
    }

    @MainActor
    private func monthValue() -> String {
        element("analysis.month").value as? String ?? ""
    }

    @MainActor
    private func waitForMonth(equalTo month: String? = nil, notEqualTo old: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let format = month != nil ? "value == %@" : "value != %@"
        let predicate = NSPredicate(format: format, month ?? old ?? "")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element("analysis.month"))], timeout: 5)
        XCTAssertEqual(result, .completed, "month is \(monthValue())", file: file, line: line)
    }

    /// Gives the stepper time to react, then checks the month never left `month`.
    @MainActor
    private func assertMonthStays(_ month: String, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value != %@", month)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element("analysis.month"))], timeout: 2)
        XCTAssertEqual(result, .timedOut, "\(message); month is \(monthValue())", file: file, line: line)
    }

    private enum Direction { case above, below }

    /// Swipes the Analisis page (or the full breakdown, `breakdown.scroll`) until `target` is hittable,
    /// starting in the side margin.
    @MainActor
    private func reveal(_ target: XCUIElement, in scrollIdentifier: String = "analysis.scroll", direction: Direction = .below) {
        let scroll = element(scrollIdentifier)
        guard scroll.exists else { return }
        for _ in 0..<12 where !(target.exists && target.isHittable && isInsideScreen(target)) {
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: direction == .below ? 0.7 : 0.3))
            let end = start.withOffset(CGVector(dx: 0, dy: direction == .below ? -220 : 220))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
    }

    /// Below the navigation bar (large or collapsed) and above the tab bar.
    @MainActor
    private func isInsideScreen(_ target: XCUIElement) -> Bool {
        let tabBar = app.tabBars.firstMatch
        let navigationBar = app.navigationBars.firstMatch
        let top = navigationBar.exists ? navigationBar.frame.maxY : 60
        let bottom = tabBar.exists ? tabBar.frame.minY : app.frame.maxY
        return target.frame.minY >= top && target.frame.maxY <= bottom
    }

    private func digitsOnly(_ label: String) -> String {
        label.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
    }
}
