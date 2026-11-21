import XCTest

final class KemanayaUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Every test starts here: a throwaway seeded store, so the month is empty, with Indonesian
    /// language and region pinned, so labels don't depend on the simulator's settings. The app opens on
    /// Beranda (D-048); these tests cover the add flow from the Riwayat tab, so they switch to it.
    @MainActor
    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(id)", "-AppleLocale", "id_ID"]
        app.launch()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 10), "the app opens on Beranda")
        let riwayat = app.tabBars.buttons["Riwayat"]
        XCTAssertTrue(riwayat.waitForExistence(timeout: 5))
        riwayat.tap()
        XCTAssertTrue(element("history.add").waitForExistence(timeout: 5))
    }

    @MainActor
    func testRiwayatStartsEmpty() throws {
        launch()
        XCTAssertTrue(element("history.empty").waitForExistence(timeout: 5), "a fresh store starts with the empty state")
    }

    /// D-067: "+" opens with the keypad up → amount → tap a subcategory (only selects) → Simpan. Then
    /// edit (opens without the keypad; tap the amount to bring it back) and delete with confirmation (D-043).
    @MainActor
    func testAddEditAndDeleteAnExpense() throws {
        launch()
        tap("history.add")
        let amount = element("add.amount")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(rupiah(amount), 0)

        // Expense is the default kind; the keypad is up; Simpan waits for an amount and a subcategory.
        XCTAssertTrue(app.buttons["Pengeluaran"].isSelected)
        XCTAssertTrue(element("add.key.1").waitForExistence(timeout: 5), "adding opens with the keypad up")
        XCTAssertFalse(element("add.save").isEnabled)

        tap("add.key.2")
        tap("add.key.5")
        tap("add.key.000")
        XCTAssertEqual(rupiah(amount), 25_000, "Rp25.000")
        tap("add.key.backspace")
        tap("add.key.backspace")
        tap("add.key.backspace")
        tap("add.key.backspace")
        XCTAssertEqual(rupiah(amount), 2)
        tap("add.key.7")
        tap("add.key.5")
        tap("add.key.0")
        tap("add.key.0")
        XCTAssertEqual(rupiah(amount), 27_500, "Rp27.500: exact amounts on the keypad")

        tap("add.tile.Makan")
        XCTAssertTrue(amount.exists, "tapping a subcategory only selects it")
        XCTAssertTrue(element("add.tile.Makan").isSelected)
        tap("add.tile.Makan")
        XCTAssertTrue(amount.exists, "tapping the selected tile doesn't save either")
        tap("add.save")
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "Simpan saves and dismisses")

        let row = transactionRow(containing: "Makan")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(digitsOnly(row.label).contains("27500 rupiah"), "row reads Makan Rp27.500: \(row.label)")
        XCTAssertFalse(element("history.empty").exists)

        // Ubah: prefilled, Makan highlighted, no keypad; tap the amount for the keypad, a new amount, Simpan.
        swipeAction(on: row, identifier: "transaction.row.edit", label: "Ubah")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(rupiah(amount), 27_500, "edit prefills the amount")
        XCTAssertTrue(element("add.tile.Makan").isSelected, "edit highlights the subcategory")
        XCTAssertFalse(element("add.key.1").exists, "editing opens without the keypad")
        tap("add.amount")
        XCTAssertTrue(element("add.key.1").waitForExistence(timeout: 5), "tapping the amount brings the keypad")
        tap("add.clear")
        XCTAssertEqual(rupiah(amount), 0)
        tap("add.key.4")
        tap("add.key.000")
        XCTAssertEqual(rupiah(amount), 4_000)
        tap("add.save")
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "Simpan saves the edit")
        let editedRow = transactionRow(containing: "Makan")
        XCTAssertTrue(editedRow.waitForExistence(timeout: 5))
        XCTAssertTrue(digitsOnly(editedRow.label).contains("4000 rupiah"), "the edit shows in the list: \(editedRow.label)")

        // Delete: swipe → Hapus → the dialog names subcategory and amount → confirm.
        swipeAction(on: editedRow, identifier: "transaction.row.delete", label: "Hapus")
        let message = app.staticTexts["Makan sebesar Rp4.000 akan dihapus permanen."]
        XCTAssertTrue(message.waitForExistence(timeout: 5), "the dialog names amount and subcategory")
        confirmDelete()
        XCTAssertTrue(element("history.empty").waitForExistence(timeout: 5), "the list is empty again")
        XCTAssertFalse(transactionRow(containing: "Makan").exists)
    }

    /// Editing: tapping another tile only selects it; Simpan saves the move.
    @MainActor
    func testEditMovesToAnotherSubcategoryWithSimpan() throws {
        launch()
        addExpense(keys: ["add.key.1", "add.key.2", "add.key.000"], subcategory: "Makan")
        swipeAction(on: transactionRow(containing: "Makan"), identifier: "transaction.row.edit", label: "Ubah")
        XCTAssertTrue(element("add.amount").waitForExistence(timeout: 5))

        tap("add.tile.Galon")
        XCTAssertTrue(element("add.amount").exists, "selecting another tile doesn't save")
        XCTAssertTrue(element("add.tile.Galon").isSelected)
        XCTAssertFalse(element("add.tile.Makan").isSelected)
        tap("add.save")
        XCTAssertTrue(element("add.amount").waitForNonExistence(timeout: 5))

        XCTAssertTrue(transactionRow(containing: "Galon").waitForExistence(timeout: 5))
        XCTAssertFalse(transactionRow(containing: "Makan").exists)
    }

    /// Editing a transaction whose tile sits far down the grid (Kopi, in Keinginan) opens with that tile
    /// already in view, without scrolling, and the label under the amount names it (D-047). Selecting
    /// another tile updates the label.
    @MainActor
    func testEditOpensWithTheSelectedTileInView() throws {
        launch()
        tap("history.add")
        XCTAssertTrue(element("add.amount").waitForExistence(timeout: 5))
        // Type first (the keypad is up), then scroll to Kopi: dragging dismisses the keypad, and a tap
        // only selects, so no stray swipe can save.
        tap("add.key.1")
        tap("add.key.8")
        tap("add.key.000")
        let scrollView = app.scrollViews["add.scroll"]
        let kopi = app.buttons["add.tile.Kopi"]
        for _ in 0..<8 where !(kopi.exists && kopi.isHittable) { dragUp(scrollView) }
        XCTAssertTrue(kopi.isHittable, "Kopi is reachable in the add sheet")
        XCTAssertFalse(element("add.key.1").exists, "dragging the list dismisses the keypad")
        kopi.tap()
        tap("add.save")
        XCTAssertTrue(element("add.amount").waitForNonExistence(timeout: 5))

        swipeAction(on: transactionRow(containing: "Kopi"), identifier: "transaction.row.edit", label: "Ubah")
        XCTAssertTrue(element("add.amount").waitForExistence(timeout: 5))
        XCTAssertTrue(kopi.waitForExistence(timeout: 5))
        XCTAssertTrue(kopi.isSelected, "edit highlights Kopi")
        XCTAssertTrue(kopi.isHittable, "the highlighted tile is in view when the sheet opens")
        let selected = element("add.selected")
        XCTAssertTrue(selected.waitForExistence(timeout: 5), "the label under the amount shows the selection")
        XCTAssertTrue(selected.label.contains("Kopi"), "the label names Kopi: \(selected.label)")

        // Jajan sits next to Kopi; in edit, tapping it only selects it, and the label follows.
        tap("add.tile.Jajan")
        XCTAssertTrue(element("add.tile.Jajan").isSelected)
        XCTAssertTrue(selected.label.contains("Jajan"), "the label follows the new selection: \(selected.label)")
        XCTAssertFalse(selected.label.contains("Kopi"))

        // Pemasukan has nothing selected, so the label goes; switching back restores it.
        app.buttons["Pemasukan"].firstMatch.tap()
        XCTAssertTrue(selected.waitForNonExistence(timeout: 5), "no selection of this kind, no label")
        app.buttons["Pengeluaran"].firstMatch.tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("Jajan"), "switching back restores the selection: \(selected.label)")
        tap("add.cancel")
        XCTAssertTrue(element("add.amount").waitForNonExistence(timeout: 5))
    }

    /// Cancelling the delete dialog keeps the row.
    @MainActor
    func testCancellingDeleteKeepsTheRow() throws {
        launch()
        addExpense(keys: ["add.key.7", "add.key.000"], subcategory: "Galon")
        let row = transactionRow(containing: "Galon")
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        swipeAction(on: row, identifier: "transaction.row.delete", label: "Hapus")
        let message = app.staticTexts["Galon sebesar Rp7.000 akan dihapus permanen."]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        cancelDelete()
        XCTAssertTrue(message.waitForNonExistence(timeout: 5))
        XCTAssertTrue(transactionRow(containing: "Galon").waitForExistence(timeout: 5))
    }

    /// Switching to Pemasukan keeps the amount and shows the income grid; Gaji + Simpan saves as income.
    @MainActor
    func testAddIncome() throws {
        launch()
        tap("history.add")
        let amount = element("add.amount")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        tap("add.key.5")
        tap("add.key.000")
        tap("add.key.000")
        XCTAssertEqual(rupiah(amount), 5_000_000)

        app.buttons["Pemasukan"].tap()
        XCTAssertEqual(rupiah(amount), 5_000_000, "switching kind keeps the amount")
        XCTAssertTrue(element("add.tile.Gaji").waitForExistence(timeout: 5))
        XCTAssertFalse(element("add.tile.Makan").exists, "the income grid has no expense subcategories")

        tap("add.tile.Gaji")
        tap("add.save")
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        let row = transactionRow(containing: "Gaji")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(digitsOnly(row.label).contains("+5000000 rupiah"), "income rows carry a plus sign: \(row.label)")
    }

    /// Backspace drops digits; an empty amount disables Simpan even with a subcategory selected; Batal
    /// saves nothing.
    @MainActor
    func testBackspaceBackToZeroDisablesSimpan() throws {
        launch()
        tap("history.add")
        let amount = element("add.amount")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        tap("add.key.4")
        tap("add.tile.Makan")
        XCTAssertTrue(element("add.save").isEnabled)
        tap("add.key.backspace")
        XCTAssertEqual(rupiah(amount), 0)
        XCTAssertFalse(element("add.save").isEnabled)
        tap("add.cancel")
        XCTAssertTrue(element("history.empty").waitForExistence(timeout: 5), "cancel saves nothing")
    }

    // MARK: - Helpers

    /// The first element with `identifier`. SwiftUI sometimes puts it on a wrapper and on the control too.
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
    private func transactionRow(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'transaction.row' AND label CONTAINS %@", text))
            .firstMatch
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

    /// A row's VoiceOver label with digit grouping removed, so amount checks don't depend on separators.
    private func digitsOnly(_ label: String) -> String {
        label.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
    }

    @MainActor
    private func addExpense(keys: [String], subcategory: String) {
        tap("history.add")
        XCTAssertTrue(element("add.amount").waitForExistence(timeout: 5))
        keys.forEach { tap($0) }
        tap("add.tile.\(subcategory)")
        tap("add.save")
        XCTAssertTrue(element("add.amount").waitForNonExistence(timeout: 5))
    }

    /// Drags the sheet's list up by 150 pt, starting near its top edge in the side margin: the
    /// scroll view runs on under the keypad (D-067), so a swipe from its centre would press a key.
    @MainActor
    private func dragUp(_ scrollView: XCUIElement) {
        let start = scrollView.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 6, dy: 180))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -150)), withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// The dialog's destructive button, by identifier.
    @MainActor
    private func confirmDelete() {
        let confirm = app.buttons.matching(identifier: "transaction.delete.confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }

    /// The delete alert's "Batal" button. It is an alert, never a popover, so the cancel button is always there.
    @MainActor
    private func cancelDelete() {
        let cancel = app.buttons["Batal"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "the delete dialog has a Batal button")
        cancel.tap()
    }
}
