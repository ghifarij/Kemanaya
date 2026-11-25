import XCTest

/// Home (D-012, D-048, D-068, D-069, D-077): the tab bar, the hero and the month it opens, quick add from a
/// pinned card, Lepas pin, the Atur sheet with its per-section limits, budgets that show only when set,
/// and budgets set from the hero's Anggaran sheet and the card menu.
final class HomeUITests: XCTestCase {
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

    /// A fresh install: the calm empty hero, the six default cards in their columns (D-068) and no
    /// budget progress (D-048), and the hero's "Anggaran" link, which is always there (D-077).
    @MainActor
    func testFreshInstallOpensOnHomeWithTheDefaultCards() throws {
        launch()
        waitForEmptyHero()
        for name in ["Makan", "Kopi", "Jajan", "Parkir", "Galon", "Hiburan"] {
            XCTAssertTrue(card(name).exists, "default pin \(name)")
        }
        // Kebutuhan on the left, Keinginan on the right, each in pin order.
        XCTAssertLessThan(card("Makan").frame.minX, card("Kopi").frame.minX)
        XCTAssertEqual(card("Makan").frame.minX, card("Galon").frame.minX, accuracy: 1)
        XCTAssertLessThan(card("Makan").frame.minY, card("Parkir").frame.minY)
        XCTAssertLessThan(card("Kopi").frame.minY, card("Jajan").frame.minY)
        XCTAssertFalse(heroValue().contains("anggaran"), "no budget, no progress: \(heroValue())")
        XCTAssertFalse(cardValue("Kopi").contains("anggaran"), "cards show no budget: \(cardValue("Kopi"))")
        XCTAssertTrue(cardValue("Kopi").contains("bulan lalu"), "without a budget the card reads last month: \(cardValue("Kopi"))")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home.income.'")).firstMatch.exists, "no income pinned, no income rows")
        XCTAssertTrue(element("home.budgets").exists, "the hero always offers Anggaran (D-077)")
    }

    /// The hero opens this month's transactions inside Home (D-068), newest first; tap = Ubah.
    @MainActor
    func testHeroOpensThisMonthsTransactions() throws {
        launch(["-debugSample", "transactions"])
        let hero = element("home.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        hero.tap()
        XCTAssertTrue(element("home.monthList").waitForExistence(timeout: 5), "the month's list is pushed")
        XCTAssertTrue(app.tabBars.buttons["Beranda"].isSelected, "still on Beranda, not a tab switch")
        XCTAssertTrue(transactionRow(containing: "Galon").waitForExistence(timeout: 5), "the newest entry is listed")
        XCTAssertTrue(element("history.day").exists, "rows sit under day headers")
        transactionRow(containing: "Galon").tap()
        XCTAssertTrue(element("add.amount").waitForExistence(timeout: 5), "tap opens Ubah")
        tap("add.cancel")
        XCTAssertTrue(element("add.amount").waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("home.hero").waitForExistence(timeout: 5))
    }

    /// Pinned income shows as a thin row below the columns; a tap quick-logs into it (D-068).
    @MainActor
    func testPinnedIncomeShowsAsARow() throws {
        launch()
        tap("home.managePins")
        toggle("Gaji")
        XCTAssertEqual(switchValue("Gaji"), "1", "Gaji is pinned")
        tap("pins.done")
        let gaji = app.buttons["home.income.Gaji"]
        XCTAssertTrue(gaji.waitForExistence(timeout: 5), "the income row shows")
        XCTAssertFalse(card("Gaji").exists, "income is a row, not a card")
        XCTAssertGreaterThan(gaji.frame.minY, card("Galon").frame.maxY, "below the columns")
        gaji.tap()
        let selected = element("add.selected")
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("Gaji"), "quick log names Gaji: \(selected.label)")
    }

    /// Unpinning every Keinginan card leaves a dashed placeholder that opens Atur (D-068).
    @MainActor
    func testAnEmptyColumnShowsAPlaceholderThatOpensAtur() throws {
        launch()
        for name in ["Kopi", "Jajan", "Hiburan"] {
            unpinFromMenu(name)
        }
        let placeholder = element("home.pinPlaceholder.keinginan")
        XCTAssertTrue(placeholder.waitForExistence(timeout: 5))
        XCTAssertFalse(element("home.pinPlaceholder.kebutuhan").exists, "Kebutuhan still has cards")
        placeholder.tap()
        XCTAssertTrue(element("pins.list").waitForExistence(timeout: 5), "the placeholder opens Atur")
    }

    @MainActor
    func testTabsSwitchBetweenBerandaAndRiwayat() throws {
        launch()
        app.tabBars.buttons["Riwayat"].tap()
        XCTAssertTrue(element("history.empty").waitForExistence(timeout: 5))
        XCTAssertFalse(element("home.hero").exists)
        app.tabBars.buttons["Beranda"].tap()
        waitForEmptyHero()
    }

    /// Tap a card → the add sheet with that subcategory preselected (D-044, D-047) and the keypad up
    /// (D-067) → amount → Simpan. Tapping the highlighted tile only keeps it selected. Both land in the
    /// right subcategory.
    @MainActor
    func testCardTapQuickAddsIntoThatSubcategory() throws {
        launch()
        card("Kopi").tap()
        let amount = element("add.amount")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        let selected = element("add.selected")
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("Kopi"), "the sheet names Kopi: \(selected.label)")
        XCTAssertFalse(app.buttons["add.save"].isEnabled, "nothing to save before an amount")
        XCTAssertTrue(element("add.key.1").waitForExistence(timeout: 5), "quick log opens with the keypad up")
        press(["1", "8", "000"])
        app.buttons["add.save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "Simpan saves and dismisses")

        waitForCardTotal("Kopi", thousands: 18)
        XCTAssertTrue(digitsOnly(heroValue()).hasPrefix("18000 rupiah"), "month total: \(heroValue())")

        // Tapping the highlighted tile doesn't save (D-067); Simpan does.
        card("Makan").tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        press(["2", "5", "000"])
        let makan = app.buttons["add.tile.Makan"]
        XCTAssertTrue(makan.waitForExistence(timeout: 5))
        XCTAssertTrue(makan.isSelected, "Makan is preselected")
        makan.tap()
        XCTAssertTrue(amount.exists, "tapping the highlighted tile doesn't save")
        XCTAssertTrue(makan.isSelected, "it stays selected")
        app.buttons["add.save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "Simpan saves")
        waitForCardTotal("Makan", thousands: 25)
        waitForCardTotal("Kopi", thousands: 18) // unchanged

        // Riwayat lists both under the right subcategory.
        app.tabBars.buttons["Riwayat"].tap()
        XCTAssertTrue(transactionRow(containing: "Kopi").waitForExistence(timeout: 5))
        XCTAssertTrue(transactionRow(containing: "Makan").exists)
    }

    /// Long-press → "Lepas pin" (D-048; the menu is Lihat detail · Ubah · Lepas pin, D-062) removes the card.
    @MainActor
    func testLepasPinRemovesTheCard() throws {
        launch()
        let jajan = card("Jajan")
        XCTAssertTrue(jajan.waitForExistence(timeout: 5))
        jajan.press(forDuration: 1.2)
        let unpin = app.buttons["home.card.unpin"].firstMatch
        XCTAssertTrue(unpin.waitForExistence(timeout: 5), "the context menu offers Lepas pin")
        XCTAssertEqual(unpin.label, "Lepas pin")
        unpin.tap()
        XCTAssertTrue(jajan.waitForNonExistence(timeout: 5), "the card is gone")
        XCTAssertGreaterThan(card("Hiburan").frame.minY, card("Kopi").frame.minY, "Hiburan moves up under Kopi")
        XCTAssertTrue(card("Makan").exists, "the other cards stay")
        XCTAssertTrue(card("Hiburan").exists)
    }

    /// Atur: each section pins up to its limit; a 7th Kebutuhan pin is refused with a note (D-068),
    /// unpin, and Home follows.
    @MainActor
    func testAturPinsUnpinsAndRefusesPastTheSectionLimit() throws {
        launch()
        tap("home.managePins")
        XCTAssertTrue(app.navigationBars.staticTexts["Atur kartu"].waitForExistence(timeout: 5))
        XCTAssertTrue(sectionHeader("kebutuhan").label.contains("3 dari 6"), "three Kebutuhan pins: \(sectionHeader("kebutuhan").label)")

        for name in ["Dapur", "Gas", "Listrik"] {
            toggle(name)
            XCTAssertEqual(switchValue(name), "1", "\(name) is pinned")
        }
        XCTAssertTrue(sectionHeader("kebutuhan").label.contains("6 dari 6"), "six Kebutuhan pins: \(sectionHeader("kebutuhan").label)")

        toggle("Air")
        XCTAssertTrue(element("pins.limitNote").waitForExistence(timeout: 3), "a 7th Kebutuhan pin shows the note")
        XCTAssertEqual(switchValue("Air"), "0", "the 7th pin is refused")
        XCTAssertTrue(sectionHeader("kebutuhan").label.contains("6 dari 6"))

        toggle("Makan")
        XCTAssertEqual(switchValue("Makan"), "0", "Makan is unpinned")
        XCTAssertTrue(sectionHeader("kebutuhan").label.contains("5 dari 6"), "five pins: \(sectionHeader("kebutuhan").label)")

        tap("pins.done")
        XCTAssertTrue(card("Listrik").waitForExistence(timeout: 5), "new pins show on Home")
        XCTAssertTrue(card("Dapur").exists)
        XCTAssertFalse(card("Makan").exists, "unpinned in Atur, gone from Home")
        XCTAssertFalse(card("Air").exists)
    }

    /// Atur: dragging a pinned row's reorder handle within its section changes the column order (D-068).
    @MainActor
    func testAturReordersCardsByDragging() throws {
        launch()
        let makanCard = card("Makan")
        let galonCard = card("Galon")
        XCTAssertTrue(galonCard.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(galonCard.frame.minY, makanCard.frame.minY, "Galon starts last in its column, Makan first")

        tap("home.managePins")
        _ = pinSwitch("Galon")
        let galonHandle = reorderHandle("Galon")
        let makanHandle = reorderHandle("Makan")
        XCTAssertTrue(galonHandle.exists, "Galon's row has a reorder handle")
        XCTAssertTrue(makanHandle.exists, "Makan's row has a reorder handle")
        // Drop just above Makan's handle centre, so Galon lands before it.
        let end = makanHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let start = galonHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.8, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        tap("pins.done")

        XCTAssertTrue(galonCard.waitForExistence(timeout: 5))
        XCTAssertTrue(element("pins.list").waitForNonExistence(timeout: 5))
        XCTAssertLessThan(galonCard.frame.minY, makanCard.frame.minY, "Galon is now first in the Kebutuhan column")
        XCTAssertEqual(galonCard.frame.minX, makanCard.frame.minX, accuracy: 1, "still in the same column")
    }

    /// With budgets set (DEBUG `-debugSample full`), the cards show them (D-041, D-068); the hero doesn't
    /// read group budgets any more (D-074).
    @MainActor
    func testBudgetsShowWhenSet() throws {
        launch(["-debugSample", "full"])
        XCTAssertTrue(element("home.hero").waitForExistence(timeout: 5))
        let hero = digitsOnly(heroValue())
        XCTAssertFalse(hero.contains("anggaran"), "no budget part in the hero (D-074): \(hero)")
        XCTAssertTrue(cardValue("Kopi").contains("anggaran"), "Kopi has a budget: \(cardValue("Kopi"))")
        XCTAssertTrue(cardValue("Jajan").contains("lewat"), "Jajan is over its budget, said plainly: \(cardValue("Jajan"))")
        XCTAssertFalse(cardValue("Makan").contains("anggaran"), "Makan has no budget: \(cardValue("Makan"))")
    }

    /// The Anggaran sheet (D-077), from the hero's link: a subcategory row reads "Belum diatur", a tap opens
    /// the budget keypad, Simpan sets it and the row reads it; the group row sets the group budget and then
    /// says how much is given to subcategories. Back on Home, Makan's card reads "sisa" and the link stays.
    @MainActor
    func testAnggaranSheetSetsSubcategoryAndGroupBudgets() throws {
        launch()
        tap("home.budgets")
        XCTAssertTrue(element("budgets.list").waitForExistence(timeout: 5), "the hero's link opens Anggaran")

        let makan = element("budgets.row.Makan")
        XCTAssertTrue(makan.waitForExistence(timeout: 5))
        XCTAssertEqual(makan.value as? String, "Belum diatur", "no budget yet")
        makan.tap()
        setBudget(["3", "0", "0", "000"])
        let makanSet = NSPredicate(format: "value BEGINSWITH %@", "anggaran 300000 rupiah")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: makanSet, object: makan)], timeout: 5), .completed,
                       "the row shows the budget: \(makan.value as? String ?? "")")

        let group = element("budgets.group.kebutuhan")
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        XCTAssertTrue((group.value as? String ?? "").hasPrefix("Belum diatur"), group.value as? String ?? "")
        group.tap()
        setBudget(["4", "000", "000"])
        let groupSet = NSPredicate(format: "value CONTAINS %@", "anggaran 4000000 rupiah")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: groupSet, object: group)], timeout: 5), .completed,
                       "the group row shows its budget: \(group.value as? String ?? "")")
        XCTAssertTrue((group.value as? String ?? "").contains("300000 rupiah untuk subkategori"),
                      "Makan's budget is a slice of Kebutuhan's: \(group.value as? String ?? "")")

        tap("budgets.done")
        XCTAssertTrue(element("budgets.list").waitForNonExistence(timeout: 5))
        XCTAssertTrue(cardValue("Makan").contains("sisa"), "Makan's card reads its budget: \(cardValue("Makan"))")
        XCTAssertFalse(heroValue().contains("anggaran"), "the hero reads no budget (D-074): \(heroValue())")
        XCTAssertTrue(element("home.budgets").exists, "the link always stays (D-077)")
    }

    /// The card menu's Atur anggaran (D-069) opens the keypad; the card then reads "sisa". Income rows
    /// have no Atur anggaran.
    @MainActor
    func testCardMenuSetsTheSubcategoryBudget() throws {
        launch()
        let kopi = card("Kopi")
        XCTAssertTrue(kopi.waitForExistence(timeout: 5))
        kopi.press(forDuration: 1.2)
        let item = app.buttons["home.card.budget"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "the context menu offers Atur anggaran")
        XCTAssertEqual(item.label, "Atur anggaran")
        item.tap()
        setBudget(["2", "0", "0", "000"])
        let predicate = NSPredicate(format: "value CONTAINS %@", "sisa")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: kopi)], timeout: 5), .completed,
                       "Kopi's card reads its budget: \(cardValue("Kopi"))")
    }

    // MARK: - Helpers

    /// Types `keys` on the budget sheet's keypad and saves.
    @MainActor
    private func setBudget(_ keys: [String], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["budget.key.1"].waitForExistence(timeout: 5), "the budget keypad opens", file: file, line: line)
        for key in keys { app.buttons["budget.key.\(key)"].tap() }
        tap("budget.save", file: file, line: line)
        XCTAssertTrue(app.buttons["budget.key.1"].waitForNonExistence(timeout: 5), "Simpan closes the keypad", file: file, line: line)
    }

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "missing \(identifier)", file: file, line: line)
        target.tap()
    }

    @MainActor
    private func card(_ name: String) -> XCUIElement {
        app.buttons["home.card.\(name)"]
    }

    /// The hero's VoiceOver value: the month's spending and each group, or the empty note.
    @MainActor
    private func heroValue() -> String {
        let hero = element("home.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 5), "missing the hero")
        return hero.value as? String ?? ""
    }

    /// Waits for the hero's calm empty note (nothing logged this month).
    @MainActor
    private func waitForEmptyHero(file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value CONTAINS %@", "Bulan ini masih kosong")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element("home.hero"))], timeout: 10)
        XCTAssertEqual(result, .completed, "the hero shows the empty note", file: file, line: line)
    }

    /// Long-press `name`'s card and choose Lepas pin.
    @MainActor
    private func unpinFromMenu(_ name: String) {
        let target = card(name)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "missing card \(name)")
        target.press(forDuration: 1.2)
        let unpin = app.buttons["home.card.unpin"].firstMatch
        XCTAssertTrue(unpin.waitForExistence(timeout: 5))
        unpin.tap()
        XCTAssertTrue(target.waitForNonExistence(timeout: 5), "\(name) is unpinned")
    }

    /// The card's VoiceOver value: this month's total, then the budget or last month.
    @MainActor
    private func cardValue(_ name: String) -> String {
        let target = card(name)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "missing card \(name)")
        return target.value as? String ?? ""
    }

    /// Waits until the card's VoiceOver value starts with `thousands` thousand rupiah, e.g. 18 → "18.000 rupiah"
    /// with any grouping separator. The card updates a moment after the add sheet dismisses.
    @MainActor
    private func waitForCardTotal(_ name: String, thousands: Int, file: StaticString = #filePath, line: UInt = #line) {
        let target = card(name)
        let predicate = NSPredicate(format: "value MATCHES %@", "\(thousands)[.,]?000 rupiah.*")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: target)], timeout: 5)
        XCTAssertEqual(result, .completed, "the \(name) card shows Rp\(thousands).000: \(target.value as? String ?? "")", file: file, line: line)
    }

    @MainActor
    private func press(_ keys: [String]) {
        for key in keys { tap("add.key.\(key)") }
    }

    /// A section's header in Atur ("Kebutuhan · 3 dari 6 dipin"), scrolled into the (lazy) list.
    @MainActor
    private func sectionHeader(_ section: String) -> XCUIElement {
        let header = element("pins.header.\(section)")
        let list = element("pins.list")
        for _ in 0..<8 where !(header.exists && header.isHittable) { list.swipeDown(velocity: .slow) }
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        return header
    }

    /// The Atur row's switch for `name`, scrolled until the switch control itself is inside the list.
    /// (A row can be "hittable" while its switch is still below the list's edge.)
    @MainActor
    private func pinSwitch(_ name: String) -> XCUIElement {
        let row = app.switches["pins.toggle.\(name)"]
        let list = element("pins.list")
        let control = { row.switches.firstMatch.exists ? row.switches.firstMatch : row }
        let isReachable = { row.exists && list.frame.insetBy(dx: 0, dy: 8).contains(control().frame) }
        for _ in 0..<8 where !isReachable() {
            if row.exists, control().frame.minY < list.frame.minY { list.swipeDown(velocity: .slow) } else { list.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(isReachable(), "could not reach \(name)")
        return row
    }

    /// The system reorder control of the pinned row for `name`: the cell's only button (its label is the
    /// system's "Urutkan ulang …", so it is found by place, not by text).
    @MainActor
    private func reorderHandle(_ name: String) -> XCUIElement {
        app.cells.containing(.switch, identifier: "pins.toggle.\(name)").buttons.firstMatch
    }

    /// Flips the switch control itself, not the label.
    @MainActor
    private func toggle(_ name: String) {
        let row = pinSwitch(name)
        let inner = row.switches.firstMatch
        if inner.exists {
            inner.tap()
        } else {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func switchValue(_ name: String) -> String? {
        pinSwitch(name).value as? String
    }

    @MainActor
    private func transactionRow(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'transaction.row' AND label CONTAINS %@", text))
            .firstMatch
    }

    private func digitsOnly(_ label: String) -> String {
        label.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
    }
}
