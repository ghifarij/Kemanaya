import XCTest

/// Pengaturan (D-060): the tab opens on **Cadangan & Ekspor** with its rows, and a fresh install's Home
/// offers "Pulihkan dari cadangan". The throwaway store has no backup folder and never writes one, so
/// "Cadangkan sekarang" is absent. The file pickers and share sheets are system UI and aren't driven here.
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
        XCTAssertTrue(app.staticTexts["Cadangan & Ekspor"].firstMatch.waitForExistence(timeout: 5) || app.staticTexts["CADANGAN & EKSPOR"].exists)
        for identifier in ["settings.backupFolder", "settings.exportBackup", "settings.restore", "settings.exportCSV"] {
            XCTAssertTrue(element(identifier).waitForExistence(timeout: 5), "missing \(identifier)")
        }
        XCTAssertTrue(element("settings.backupStatus").label.contains("Belum dipilih"), "no folder in a throwaway store")
        XCTAssertFalse(element("settings.backupNow").exists, "Cadangkan sekarang needs a folder")
        XCTAssertFalse(element("settings.backupOff").exists)
    }

    @MainActor
    func testRestoreOpensTheFilePicker() throws {
        launch()
        openPengaturan()
        let restore = element("settings.restore")
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        // The system document picker; cancel it, nothing changes.
        let cancel = app.buttons["Batal"].firstMatch
        if cancel.waitForExistence(timeout: 10) { cancel.tap() }
        XCTAssertTrue(element("settings.restore").waitForExistence(timeout: 5))
        XCTAssertFalse(element("restore.status").exists, "a cancelled pick leaves no status")
    }

    /// A fresh install (no transactions, no rollups) offers to restore on Home; any data hides it.
    @MainActor
    func testHomeOffersRestoreOnlyOnAFreshInstall() throws {
        launch()
        XCTAssertTrue(element("home.empty").waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.restore").exists, "a fresh install offers Pulihkan dari cadangan")

        app.terminate()
        launch(["-debugSample", "transactions"])
        XCTAssertTrue(element("home.expenses").waitForExistence(timeout: 5))
        XCTAssertFalse(element("home.restore").exists, "a store with history doesn't")
    }

    // MARK: - Helpers

    /// The first element with `identifier`. SwiftUI sometimes puts it on a wrapper and on the control too.
    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
