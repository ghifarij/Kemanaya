import XCTest

final class KemanayaUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Every test starts here: a throwaway seeded store, so the month is empty, with Indonesian
    /// language and region pinned, so labels don't depend on the simulator's settings.
    @MainActor
    private func launch() {
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(id)", "-AppleLocale", "id_ID"]
        app.launch()
    }

    @MainActor
    func testAppLaunchesToTheRootScreen() throws {
        launch()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("month.empty").exists, "a fresh store starts with the empty state")
    }

    /// D-013: "+" → amount → tap a subcategory saves. Then edit (D-044: tapping the highlighted tile
    /// saves) and delete with confirmation (D-043).
    @MainActor
    func testAddEditAndDeleteAnExpense() throws {
        launch()
        tap("month.add")
        let amount = element("add.amount")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(rupiah(amount), 0)

        // Expense is the default kind; tiles are disabled until there is an amount.
        XCTAssertTrue(app.buttons["Pengeluaran"].isSelected)
        XCTAssertFalse(element("add.tile.Makan").isEnabled)

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
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "tapping a subcategory saves and dismisses")

        let row = transactionRow(containing: "Makan")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(digitsOnly(row.label).contains("27500 rupiah"), "row reads Makan Rp27.500: \(row.label)")
        XCTAssertFalse(element("month.empty").exists)

        // Ubah: prefilled, Makan highlighted; a new amount, then tap the highlighted tile to save.
        swipeAction(on: row, identifier: "month.row.edit", label: "Ubah")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertEqual(rupiah(amount), 27_500, "edit prefills the amount")
        XCTAssertTrue(element("add.tile.Makan").isSelected, "edit highlights the subcategory")
        tap("add.clear")
        XCTAssertEqual(rupiah(amount), 0)
        tap("add.key.4")
        tap("add.key.000")
        XCTAssertEqual(rupiah(amount), 4_000)
        tap("add.tile.Makan")
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "tapping the highlighted tile saves")
        let editedRow = transactionRow(containing: "Makan")
        XCTAssertTrue(editedRow.waitForExistence(timeout: 5))
        XCTAssertTrue(digitsOnly(editedRow.label).contains("4000 rupiah"), "the edit shows in the list: \(editedRow.label)")

        // Delete: swipe → Hapus → the dialog names subcategory and amount → confirm.
        swipeAction(on: editedRow, identifier: "month.row.delete", label: "Hapus")
        let message = app.staticTexts["Makan sebesar Rp4.000 akan dihapus permanen."]
        XCTAssertTrue(message.waitForExistence(timeout: 5), "the dialog names amount and subcategory")
        confirmDelete()
        XCTAssertTrue(element("month.empty").waitForExistence(timeout: 5), "the list is empty again")
        XCTAssertFalse(transactionRow(containing: "Makan").exists)
    }

    /// Editing: tapping another tile only selects it; Simpan saves the move.
    @MainActor
    func testEditMovesToAnotherSubcategoryWithSimpan() throws {
        launch()
        addExpense(keys: ["add.key.1", "add.key.2", "add.key.000"], subcategory: "Makan")
        swipeAction(on: transactionRow(containing: "Makan"), identifier: "month.row.edit", label: "Ubah")
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
        tap("month.add")
        XCTAssertTrue(element("add.amount").waitForExistence(timeout: 5))
        // Scroll to Kopi while the amount is 0, so the tiles are disabled and no swipe can save.
        let scrollView = app.scrollViews["add.scroll"]
        let kopi = app.buttons["add.tile.Kopi"]
        for _ in 0..<8 where !(kopi.exists && kopi.isHittable) { scrollView.swipeUp(velocity: .slow) }
        XCTAssertTrue(kopi.isHittable, "Kopi is reachable in the add sheet")
        tap("add.key.1")
        tap("add.key.8")
        tap("add.key.000")
        kopi.tap()
        XCTAssertTrue(element("add.amount").waitForNonExistence(timeout: 5))

        swipeAction(on: transactionRow(containing: "Kopi"), identifier: "month.row.edit", label: "Ubah")
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

        swipeAction(on: row, identifier: "month.row.delete", label: "Hapus")
        let message = app.staticTexts["Galon sebesar Rp7.000 akan dihapus permanen."]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        cancelDelete()
        XCTAssertTrue(message.waitForNonExistence(timeout: 5))
        XCTAssertTrue(transactionRow(containing: "Galon").waitForExistence(timeout: 5))
    }

    /// Switching to Pemasukan keeps the amount and shows the income grid; Gaji saves as income.
    @MainActor
    func testAddIncome() throws {
        launch()
        tap("month.add")
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
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        let row = transactionRow(containing: "Gaji")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(digitsOnly(row.label).contains("+5000000 rupiah"), "income rows carry a plus sign: \(row.label)")
    }

    /// Backspace drops digits; an empty amount keeps the tiles disabled; Batal saves nothing.
    @MainActor
    func testBackspaceBackToZeroDisablesTiles() throws {
        launch()
        tap("month.add")
        let amount = element("add.amount")
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        tap("add.key.4")
        XCTAssertTrue(element("add.tile.Makan").isEnabled)
        tap("add.key.backspace")
        XCTAssertEqual(rupiah(amount), 0)
        XCTAssertFalse(element("add.tile.Makan").isEnabled)
        tap("add.cancel")
        XCTAssertTrue(element("month.empty").waitForExistence(timeout: 5), "cancel saves nothing")
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
            .matching(NSPredicate(format: "identifier == 'month.row' AND label CONTAINS %@", text))
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
        tap("month.add")
        XCTAssertTrue(element("add.amount").waitForExistence(timeout: 5))
        keys.forEach { tap($0) }
        tap("add.tile.\(subcategory)")
        XCTAssertTrue(element("add.amount").waitForNonExistence(timeout: 5))
    }

    /// The dialog's destructive button, by identifier.
    @MainActor
    private func confirmDelete() {
        let confirm = app.buttons.matching(identifier: "month.delete.confirm").firstMatch
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
