import XCTest

/// The introduction (D-063) and the screen shown when the store won't open.
///
/// Every UI test runs on a throwaway store (`-inMemoryStore`), which never shows the introduction by
/// itself; these tests ask for it with `-showOnboarding`. The store error screen is reached with the
/// DEBUG `-simulateStoreError plain | exports`, which opens no store at all. The file picker and share
/// sheet are system UI and are only opened and cancelled here.
final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A throwaway seeded store with Indonesian language and region, plus `extraArguments`.
    @MainActor
    private func launch(_ extraArguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-AppleLanguages", "(id)", "-AppleLocale", "id_ID"] + extraArguments
        app.launch()
    }

    @MainActor
    private func launchWithIntroduction() {
        launch(["-showOnboarding"])
        XCTAssertTrue(title(1).waitForExistence(timeout: 10), "the introduction opens on its first page")
    }

    // MARK: - Introduction

    /// Without the launch argument a UI test goes straight to Beranda.
    @MainActor
    func testThrowawayStoreSkipsTheIntroduction() throws {
        launch()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(title(1).exists)
        XCTAssertFalse(button("onboarding.skip").exists)
    }

    @MainActor
    func testLewatiClosesTheIntroduction() throws {
        launchWithIntroduction()
        tap("onboarding.skip")
        XCTAssertTrue(title(1).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 5), "Beranda is underneath")
    }

    /// Lanjut through the three pages; the last has Mulai and Pulihkan dari cadangan instead of Lewati.
    @MainActor
    func testPagingThroughAndMulai() throws {
        launchWithIntroduction()
        XCTAssertTrue(button("onboarding.next").exists)
        XCTAssertFalse(button("onboarding.start").exists)
        XCTAssertTrue(app.staticTexts["Kemana ya uangku?"].exists)

        tap("onboarding.next")
        XCTAssertTrue(waitUntilHittable(title(2)), "page 2: the cards")
        let legend = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Batang tebal'")).firstMatch
        XCTAssertTrue(legend.exists, "the mini-bar legend (D-040)")

        tap("onboarding.next")
        XCTAssertTrue(waitUntilHittable(title(3)), "page 3: Kebutuhan and Keinginan")
        XCTAssertTrue(button("onboarding.start").waitForExistence(timeout: 5))
        XCTAssertTrue(button("onboarding.restore").exists)
        XCTAssertFalse(button("onboarding.next").exists)
        // Lewati is hidden from accessibility on the last page, so it may not exist at all.
        let skip = button("onboarding.skip")
        XCTAssertFalse(skip.exists && skip.isHittable, "no Lewati on the last page")

        tap("onboarding.start")
        XCTAssertTrue(title(3).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 5))
    }

    /// Swiping moves between pages too.
    @MainActor
    func testSwipingChangesPages() throws {
        launchWithIntroduction()
        title(1).swipeLeft()
        XCTAssertTrue(waitUntilHittable(title(2)))
        title(2).swipeRight()
        XCTAssertTrue(waitUntilHittable(title(1)))
    }

    /// Pulihkan dari cadangan closes the introduction and opens the backup picker on Beranda (D-060).
    @MainActor
    func testPulihkanOpensTheBackupPickerOnBeranda() throws {
        launchWithIntroduction()
        tap("onboarding.next")
        tap("onboarding.next")
        tap("onboarding.restore")
        XCTAssertTrue(title(3).waitForNonExistence(timeout: 5))
        // The system document picker; cancel it, nothing changes. In Indonesian its button reads "Batalkan".
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Batalkan", "Batal"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "the backup picker opens")
        cancel.tap()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 5), "back on Beranda")
        XCTAssertTrue(element("home.restore").waitForExistence(timeout: 5), "the fresh install's link stays")
        XCTAssertFalse(element("restore.status").exists, "a cancelled pick leaves no status")
    }

    /// Pengaturan's "Lihat pengenalan lagi" shows it again from the first page.
    @MainActor
    func testLihatPengenalanLagi() throws {
        launch()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 10))
        let tab = app.tabBars.buttons["Pengaturan"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        let row = element("settings.introduction")
        let form = element("settings.form")
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        for _ in 0..<8 where !(row.exists && row.isHittable) { form.swipeUp() }
        XCTAssertTrue(row.isHittable, "Tentang has Lihat pengenalan lagi")
        row.tap()
        XCTAssertTrue(title(1).waitForExistence(timeout: 5), "the introduction opens on its first page")
        tap("onboarding.skip")
        XCTAssertTrue(title(1).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Pengaturan"].waitForExistence(timeout: 5), "back where it was opened")
    }

    // MARK: - Store error

    /// Nothing to save: the explanation, the code, and no export buttons. Never the tabs.
    @MainActor
    func testStoreErrorWithNothingToSave() throws {
        launch(["-simulateStoreError", "plain"])
        XCTAssertTrue(element("storeError.title").waitForExistence(timeout: 10))
        XCTAssertTrue(element("storeError.nothingToSave").exists)
        XCTAssertTrue(element("storeError.code").exists)
        XCTAssertFalse(button("storeError.exportBackup").exists)
        XCTAssertFalse(button("storeError.exportStoreFiles").exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists, "the app doesn't open on a store it couldn't read")
    }

    /// A backup folder and store files: both export buttons, and the backup one opens the share sheet.
    @MainActor
    func testStoreErrorOffersTheLastBackupAndTheFiles() throws {
        launch(["-simulateStoreError", "exports"])
        XCTAssertTrue(element("storeError.title").waitForExistence(timeout: 10))
        let export = button("storeError.exportBackup")
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertTrue(button("storeError.exportStoreFiles").exists)
        XCTAssertFalse(element("storeError.nothingToSave").exists)
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<6 where !export.isHittable { scroll.swipeUp() }
        export.tap()
        // The system share sheet; close it, nothing changes.
        let close = app.buttons["Tutup"].firstMatch
        if close.waitForExistence(timeout: 10) {
            close.tap()
        } else {
            app.otherElements["ActivityListView"].firstMatch.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(element("storeError.title").waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    @MainActor
    private func title(_ page: Int) -> XCUIElement {
        app.staticTexts["onboarding.title.\(page)"]
    }

    @MainActor
    private func button(_ identifier: String) -> XCUIElement {
        app.buttons[identifier].firstMatch
    }

    @MainActor
    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = button(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "missing \(identifier)", file: file, line: line)
        target.tap()
    }

    /// The first element with `identifier`. SwiftUI sometimes puts it on a wrapper and on the control too.
    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// A page's title is laid out next to the visible one too; it counts once it is on screen.
    @MainActor
    private func waitUntilHittable(_ target: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: target)
        return XCTWaiter().wait(for: [hittable], timeout: timeout) == .completed
    }
}
