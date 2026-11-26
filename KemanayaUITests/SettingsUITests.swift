import XCTest

/// Pengaturan (D-060, D-062, D-078): Tampilan, Subkategori, **Cadangan & Ekspor** and Tentang, and a fresh install's
/// Home offers "Pulihkan dari cadangan". The throwaway store has no backup folder and never writes one, so
/// "Cadangkan sekarang" is absent. The file pickers and share sheets are system UI and aren't driven here.
///
/// Phase 10 (D-062): group budgets on the keypad, Kelola subkategori (add, the name rules, delete without
/// history, hide with history and Tampilkan), and the Home card menu's Ubah.
final class SettingsUITests: XCTestCase {
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
    private func openPengaturan() {
        let tab = app.tabBars.buttons["Pengaturan"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        XCTAssertTrue(app.navigationBars["Pengaturan"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTabShowsTheBackupAndExportRows() throws {
        launch()
        openPengaturan()
        XCTAssertTrue(element("settings.appearance").waitForExistence(timeout: 5), "Tampilan comes first (D-078)")
        XCTAssertFalse(element("settings.budget.kebutuhan").exists, "budgets moved to Home's Anggaran sheet (D-077)")
        XCTAssertTrue(element("settings.subcategories").exists)
        for identifier in ["settings.backupFolder", "settings.exportBackup", "settings.restore", "settings.exportCSV", "settings.version"] {
            XCTAssertTrue(reveal(element(identifier)), "missing \(identifier)")
        }
        XCTAssertTrue(app.staticTexts["Cadangan & Ekspor"].firstMatch.exists || app.staticTexts["CADANGAN & EKSPOR"].exists)
        XCTAssertTrue(reveal(element("settings.introduction")), "Tentang has Lihat pengenalan lagi (D-063)")
        // The status sits inside the folder row's button, which may read it as part of its own label.
        let status = element("settings.backupStatus")
        let statusLabel = status.exists ? status.label : element("settings.backupFolder").label
        XCTAssertTrue(statusLabel.contains("Belum dipilih"), "no folder in a throwaway store: \(statusLabel)")
        XCTAssertFalse(element("settings.backupNow").exists, "Cadangkan sekarang needs a folder")
        XCTAssertFalse(element("settings.backupOff").exists)
    }

    @MainActor
    func testRestoreOpensTheFilePicker() throws {
        launch()
        openPengaturan()
        let restore = element("settings.restore")
        XCTAssertTrue(reveal(restore))
        restore.tap()
        // The system document picker; cancel it, nothing changes. In Indonesian its button reads "Batalkan".
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Batalkan", "Batal"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "the backup picker opens")
        cancel.tap()
        XCTAssertTrue(element("settings.restore").waitForExistence(timeout: 5))
        XCTAssertFalse(element("restore.status").exists, "a cancelled pick leaves no status")
    }

    /// A fresh install (no transactions, no rollups) offers to restore on Home; any data hides it.
    @MainActor
    func testHomeOffersRestoreOnlyOnAFreshInstall() throws {
        launch()
        XCTAssertTrue(element("home.hero").waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.restore").waitForExistence(timeout: 5), "a fresh install offers Pulihkan dari cadangan")

        app.terminate()
        launch(["-debugSample", "transactions"])
        let hero = element("home.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        XCTAssertFalse((hero.value as? String ?? "").contains("Bulan ini masih kosong"), "the month has data")
        XCTAssertFalse(element("home.restore").exists, "a store with history doesn't")
    }

    // MARK: - Budgets (D-062, D-077)

    /// A group budget is typed on the keypad from Home's Anggaran sheet and saved; Hapus anggaran clears
    /// it; saving 0 clears it too.
    @MainActor
    func testGroupBudgetSetAndClear() throws {
        launch()
        let link = element("home.budgets")
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        let row = element("budgets.group.kebutuhan")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(value(row).hasPrefix("Belum diatur"), "no budget on a fresh install: \(value(row))")

        row.tap()
        XCTAssertTrue(app.buttons["budget.key.3"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["budget.remove"].exists, "nothing to remove yet")
        for key in ["3", "000", "000"] { app.buttons["budget.key.\(key)"].tap() }
        XCTAssertTrue(digitsOnly(element("budget.amount").label).contains("3000000 rupiah"), element("budget.amount").label)
        app.buttons["budget.save"].tap()
        XCTAssertTrue(app.buttons["budget.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(digitsOnly(value(row)).contains("anggaran 3000000 rupiah"), "the row shows the budget: \(value(row))")

        row.tap()
        XCTAssertTrue(app.buttons["budget.remove"].waitForExistence(timeout: 5))
        app.buttons["budget.remove"].tap()
        XCTAssertTrue(app.buttons["budget.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(value(row).hasPrefix("Belum diatur"), value(row))

        // The Keinginan section follows every Kebutuhan subcategory row (D-077), so the list may not have
        // built its group row yet.
        let keinginan = element("budgets.group.keinginan")
        let list = element("budgets.list")
        // Fully below the sheet's navigation bar (the list runs under it) and above the list's bottom edge.
        let navigationBar = app.navigationBars.firstMatch
        let top = { max(list.frame.minY, navigationBar.frame.maxY) + 8 }
        let isReachable = { keinginan.exists && keinginan.isHittable && keinginan.frame.minY >= top() && keinginan.frame.maxY <= list.frame.maxY - 8 }
        for _ in 0..<10 where !isReachable() {
            if keinginan.exists, keinginan.frame.minY < top() { list.swipeDown() } else { list.swipeUp() }
        }
        XCTAssertTrue(isReachable(), "could not reach the Keinginan group row")
        // Saving 0 is not a budget.
        keinginan.tap()
        XCTAssertTrue(app.buttons["budget.save"].waitForExistence(timeout: 5))
        app.buttons["budget.save"].tap()
        XCTAssertTrue(app.buttons["budget.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(value(keinginan).hasPrefix("Belum diatur"), value(keinginan))
    }

    /// An element's VoiceOver value as text.
    @MainActor
    private func value(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    // MARK: - Kelola subkategori (D-062)

    /// "+" adds an expense subcategory to the group picked; Simpan waits for a valid, free name.
    @MainActor
    func testAddASubcategory() throws {
        launch()
        openSubcategories()
        tap("subcategories.add")
        let save = app.buttons["editor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "nothing typed yet")

        let emoji = element("editor.emoji")
        emoji.tap()
        emoji.typeText("🍜")
        let name = element("editor.name")
        name.tap()
        name.typeText("kopi")
        XCTAssertTrue(element("editor.nameProblem").waitForExistence(timeout: 5), "Kopi is taken, ignoring case")
        XCTAssertFalse(save.isEnabled)
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "Bakso goreng")
        XCTAssertTrue(element("editor.nameProblem").label.contains("satu kata"), element("editor.nameProblem").label)
        XCTAssertFalse(save.isEnabled)
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        XCTAssertTrue(element("editor.counter").label.contains("5"), element("editor.counter").label)
        XCTAssertFalse(element("editor.nameProblem").exists)

        app.buttons["Keinginan"].firstMatch.tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        let row = element("subcategories.row.Bakso")
        XCTAssertTrue(reveal(row, in: "subcategories.list"), "Bakso is listed")
    }

    /// No history: the confirmation says it is deleted, and it is gone.
    @MainActor
    func testDeleteASubcategoryWithoutHistory() throws {
        launch()
        openSubcategories()
        let kado = element("subcategories.row.Kado")
        XCTAssertTrue(reveal(kado, in: "subcategories.list"))
        kado.tap()
        tap("editor.remove")
        let confirm = app.buttons["editor.remove.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(confirm.label, "Hapus subkategori")
        confirm.tap()
        XCTAssertTrue(kado.waitForNonExistence(timeout: 5))
        XCTAssertFalse(element("subcategories.hidden.Kado").exists, "deleted, not hidden")
    }

    /// With history it is hidden instead (D-006), which unpins it (D-049); Tampilkan shows it, unpinned.
    @MainActor
    func testHideASubcategoryWithHistoryAndShowItAgain() throws {
        launch(["-debugSample", "transactions"])
        XCTAssertTrue(app.buttons["home.card.Kopi"].waitForExistence(timeout: 5))
        openSubcategories()
        let kopi = element("subcategories.row.Kopi")
        XCTAssertTrue(reveal(kopi, in: "subcategories.list"))
        kopi.tap()
        XCTAssertTrue(element("editor.removeNote").waitForExistence(timeout: 5), "the editor says it will be hidden")
        tap("editor.remove")
        let confirm = app.buttons["editor.remove.confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertEqual(confirm.label, "Sembunyikan")
        confirm.tap()

        let unhide = app.buttons["subcategories.unhide.Kopi"]
        XCTAssertTrue(reveal(unhide, in: "subcategories.list"), "Kopi sits in Tersembunyi")
        XCTAssertFalse(kopi.exists)

        app.tabBars.buttons["Beranda"].tap()
        XCTAssertTrue(app.buttons["home.card.Kopi"].waitForNonExistence(timeout: 5), "hiding unpins (D-049)")

        app.tabBars.buttons["Pengaturan"].tap() // still on Kelola subkategori
        XCTAssertTrue(reveal(unhide, in: "subcategories.list"))
        unhide.tap()
        XCTAssertTrue(reveal(kopi, in: "subcategories.list"), "Kopi is back in Keinginan")
        app.tabBars.buttons["Beranda"].tap()
        XCTAssertFalse(app.buttons["home.card.Kopi"].waitForExistence(timeout: 2), "not pinned again (D-049)")
    }

    /// Income has no group and no budget (D-005, D-041); the last visible income can't be removed.
    @MainActor
    func testIncomeHasNoGroupOrBudget() throws {
        launch()
        openSubcategories()
        app.buttons["Pemasukan"].firstMatch.tap()
        let gaji = element("subcategories.row.Gaji")
        XCTAssertTrue(gaji.waitForExistence(timeout: 5))
        gaji.tap()
        XCTAssertTrue(element("editor.name").waitForExistence(timeout: 5))
        XCTAssertFalse(element("editor.group").exists)
        XCTAssertFalse(element("editor.budget").exists)
        XCTAssertTrue(element("editor.remove").exists)
        tap("editor.cancel")
    }

    /// The card menu is Lihat detail · Ubah · Lepas pin (D-012, D-062); Ubah opens the editor, and a
    /// rename shows on the card. Kind and group are fixed (D-004).
    @MainActor
    func testUbahFromAHomeCardRenames() throws {
        launch()
        let card = app.buttons["home.card.Jajan"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.press(forDuration: 1.2)
        let edit = app.buttons["home.card.edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "the menu offers Ubah")
        XCTAssertEqual(edit.label, "Ubah")
        XCTAssertTrue(app.buttons["home.card.detail"].firstMatch.exists)
        XCTAssertTrue(app.buttons["home.card.unpin"].firstMatch.exists)
        edit.tap()

        let name = element("editor.name")
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Jajan")
        XCTAssertFalse(app.buttons["Kebutuhan"].exists, "the group is fixed after creation")
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "Camilan")
        tap("editor.save")
        XCTAssertTrue(app.buttons["home.card.Camilan"].waitForExistence(timeout: 5), "the card follows the rename")
    }

    // MARK: - Helpers

    @MainActor
    private func openSubcategories() {
        openPengaturan()
        let row = element("settings.subcategories")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(element("subcategories.list").waitForExistence(timeout: 5))
    }

    /// Taps the button with `identifier`.
    @MainActor
    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = app.buttons[identifier].firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5), "missing \(identifier)", file: file, line: line)
        target.tap()
    }

    /// Scrolls the list `identifier` (Pengaturan's form by default) down, then back up, until `target` is hittable.
    /// - Returns: whether it is.
    @MainActor
    @discardableResult
    private func reveal(_ target: XCUIElement, in identifier: String = "settings.form") -> Bool {
        let list = element(identifier)
        guard list.waitForExistence(timeout: 5) else { return false }
        for _ in 0..<8 {
            if target.exists, target.isHittable { return true }
            list.swipeUp()
        }
        for _ in 0..<12 {
            if target.exists, target.isHittable { return true }
            list.swipeDown()
        }
        return target.exists && target.isHittable
    }

    /// The first element with `identifier`. SwiftUI sometimes puts it on a wrapper and on the control too.
    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Drops the grouping separators: "3.000.000 rupiah" → "3000000 rupiah".
    private func digitsOnly(_ label: String) -> String {
        label.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
    }
}
