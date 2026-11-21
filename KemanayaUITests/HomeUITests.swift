import XCTest

/// Home (D-012, D-048): the tab bar, quick add from a pinned card, Lepas pin, the Atur sheet and
/// budgets that show only when set.
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

    /// A fresh install: the calm empty state, the six default cards (D-012) and no budget UI (D-048).
    @MainActor
    func testFreshInstallOpensOnHomeWithTheDefaultCards() throws {
        launch()
        XCTAssertTrue(element("home.empty").waitForExistence(timeout: 5))
        for name in ["Makan", "Kopi", "Jajan", "Parkir", "Galon", "Hiburan"] {
            XCTAssertTrue(card(name).exists, "default pin \(name)")
        }
        XCTAssertFalse(element("home.budget.kebutuhan").exists, "no budget, no progress")
        XCTAssertFalse(element("home.budget.keinginan").exists)
        XCTAssertFalse(digitsOnly(cardValue("Kopi")).contains("anggaran"), "cards show no budget: \(cardValue("Kopi"))")
    }

    @MainActor
    func testTabsSwitchBetweenBerandaAndRiwayat() throws {
        launch()
        app.tabBars.buttons["Riwayat"].tap()
        XCTAssertTrue(element("history.empty").waitForExistence(timeout: 5))
        XCTAssertFalse(element("home.empty").exists)
        app.tabBars.buttons["Beranda"].tap()
        XCTAssertTrue(element("home.empty").waitForExistence(timeout: 5))
    }

    /// Tap a card → the add sheet with that subcategory preselected (D-044, D-047) → amount → Simpan.
    /// Then the same with the highlighted tile instead of Simpan. Both land in the right subcategory.
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
        press(["1", "8", "000"])
        app.buttons["add.save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "Simpan saves and dismisses")

        waitForCardTotal("Kopi", thousands: 18)
        XCTAssertTrue(element("home.empty").waitForNonExistence(timeout: 5), "the month has a transaction now")
        XCTAssertTrue(digitsOnly(element("home.expenses").label).contains("18000"), "month total: \(element("home.expenses").label)")

        // The highlighted tile saves too (D-044).
        card("Makan").tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        press(["2", "5", "000"])
        let makan = app.buttons["add.tile.Makan"]
        XCTAssertTrue(makan.waitForExistence(timeout: 5))
        XCTAssertTrue(makan.isSelected, "Makan is preselected")
        makan.tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "tapping the highlighted tile saves")
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
        XCTAssertTrue(card("Makan").exists, "the other cards stay")
        XCTAssertTrue(card("Hiburan").exists)
    }

    /// Atur: pin up to nine, a 10th is refused with a note (D-012, D-048), unpin, and Home follows.
    @MainActor
    func testAturPinsUnpinsAndRefusesATenthPin() throws {
        launch()
        tap("home.managePins")
        XCTAssertTrue(app.navigationBars.staticTexts["Atur kartu"].waitForExistence(timeout: 5))
        XCTAssertTrue(pinHeader().label.localizedCaseInsensitiveContains("6 dari 9"), "six default pins: \(pinHeader().label)")

        for name in ["Dapur", "Gas", "Listrik"] {
            toggle(name)
            XCTAssertEqual(switchValue(name), "1", "\(name) is pinned")
        }
        XCTAssertTrue(pinHeader().label.localizedCaseInsensitiveContains("9 dari 9"), "nine pins: \(pinHeader().label)")

        toggle("Air")
        XCTAssertTrue(element("pins.limitNote").waitForExistence(timeout: 3), "a 10th pin shows the note")
        XCTAssertEqual(switchValue("Air"), "0", "the 10th pin is refused")
        XCTAssertTrue(pinHeader().label.localizedCaseInsensitiveContains("9 dari 9"))

        toggle("Makan")
        XCTAssertEqual(switchValue("Makan"), "0", "Makan is unpinned")
        XCTAssertTrue(pinHeader().label.localizedCaseInsensitiveContains("8 dari 9"), "eight pins: \(pinHeader().label)")

        tap("pins.done")
        XCTAssertTrue(card("Listrik").waitForExistence(timeout: 5), "new pins show on Home")
        XCTAssertTrue(card("Dapur").exists)
        XCTAssertFalse(card("Makan").exists, "unpinned in Atur, gone from Home")
        XCTAssertFalse(card("Air").exists)
    }

    /// Atur: dragging a pinned row's reorder handle changes the card order on Home (D-048).
    @MainActor
    func testAturReordersCardsByDragging() throws {
        launch()
        let makanCard = card("Makan")
        let hiburanCard = card("Hiburan")
        XCTAssertTrue(hiburanCard.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(hiburanCard.frame.minY, makanCard.frame.minY, "Hiburan starts last, Makan first")

        tap("home.managePins")
        _ = pinSwitch("Hiburan")
        let hiburanHandle = reorderHandle("Hiburan")
        let makanHandle = reorderHandle("Makan")
        XCTAssertTrue(hiburanHandle.exists, "Hiburan's row has a reorder handle")
        XCTAssertTrue(makanHandle.exists, "Makan's row has a reorder handle")
        // Drop just above Makan's handle centre, so Hiburan lands before it.
        let end = makanHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let start = hiburanHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.8, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        tap("pins.done")

        XCTAssertTrue(hiburanCard.waitForExistence(timeout: 5))
        XCTAssertTrue(element("pins.header").waitForNonExistence(timeout: 5))
        XCTAssertEqual(hiburanCard.frame.minY, makanCard.frame.minY, accuracy: 1, "Hiburan moved to the first row")
        XCTAssertLessThan(hiburanCard.frame.minX, makanCard.frame.minX, "Hiburan is now the first card")
    }

    /// With budgets set (DEBUG `-debugSample full`), Home shows group budgets and card budgets (D-041).
    @MainActor
    func testBudgetsShowWhenSet() throws {
        launch(["-debugSample", "full"])
        XCTAssertTrue(element("home.budget.kebutuhan").waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.budget.keinginan").exists)
        XCTAssertFalse(element("home.empty").exists)
        XCTAssertTrue(cardValue("Kopi").contains("anggaran"), "Kopi has a budget: \(cardValue("Kopi"))")
        XCTAssertTrue(cardValue("Jajan").contains("lewat"), "Jajan is over its budget, said plainly: \(cardValue("Jajan"))")
        XCTAssertFalse(cardValue("Makan").contains("anggaran"), "Makan has no budget: \(cardValue("Makan"))")
    }

    // MARK: - Helpers

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

    /// The card's VoiceOver value: this month's total, its direction and the budget when set.
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

    /// The pinned section's header, scrolled back into the (lazy) list when the rows below were reached.
    @MainActor
    private func pinHeader() -> XCUIElement {
        let header = element("pins.header")
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

    /// The system reorder control of the pinned row for `name`: the cell's only button
    /// (its label is the system's "Urutkan ulang …", so it is found by place, not by text).
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
