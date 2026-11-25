import XCTest

/// Riwayat as History (D-053, D-057): month and day headers, paging back through the 13-month window,
/// search by text and by amount prefix, suggestions while typing, the no-results state, and tap = Ubah /
/// swipe = Hapus on a row. Sample data comes from the DEBUG `-debugSample transactions` argument: this
/// month, last month, two to five months back, and seven to twelve months back (with a "Kopi tubruk"
/// Rp18.000 in each).
final class HistoryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A throwaway seeded store with the sample transactions, Indonesian language and region, on Riwayat.
    @MainActor
    private func launchOnRiwayat() {
        app = XCUIApplication()
        app.launchArguments = [
            "-inMemoryStore", "-AppleLanguages", "(id)", "-AppleLocale", "id_ID", "-debugSample", "transactions",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 10), "the app opens on Beranda")
        let riwayat = app.tabBars.buttons["Riwayat"]
        XCTAssertTrue(riwayat.waitForExistence(timeout: 5))
        riwayat.tap()
        XCTAssertTrue(element("history.list").waitForExistence(timeout: 5))
    }

    /// The newest month first, with its header and sticky day headers; scrolling loads older months until
    /// the oldest month of the window.
    @MainActor
    func testMonthAndDayHeadersAndPagingBackThroughTheWindow() throws {
        launchOnRiwayat()
        let month = element("history.month")
        XCTAssertTrue(month.waitForExistence(timeout: 5))
        XCTAssertTrue(month.label.contains(monthTitle(monthsBack: 0)), "the newest month comes first: \(month.label)")
        XCTAssertTrue(month.label.contains("pengeluaran"), "the month header reads its total: \(month.label)")
        let day = element("history.day")
        XCTAssertTrue(day.exists)
        XCTAssertFalse(day.label.contains("rupiah"), "the day header is the date only (D-073): \(day.label)")
        XCTAssertTrue(transactionRow(containing: "Galon").exists, "the newest entry is in view")

        // Twelve months back: scrolling reaches it.
        let oldest = monthHeader(containing: monthTitle(monthsBack: 12))
        let list = element("history.list")
        for _ in 0..<40 where !oldest.exists { list.swipeUp() }
        XCTAssertTrue(oldest.exists, "scrolling reaches the window's oldest month")
        XCTAssertTrue(transactionRow(containing: "Token listrik").waitForExistence(timeout: 5))
    }

    /// Search matches the note as text, and amounts that start with the typed digits (D-053, D-057).
    @MainActor
    func testSearchByTextAndByAmount() throws {
        launchOnRiwayat()
        search("martabak")
        XCTAssertTrue(transactionRow(containing: "Jajan").waitForExistence(timeout: 5), "the note matches")
        XCTAssertFalse(transactionRow(containing: "Galon").exists, "other rows are filtered out")
        XCTAssertTrue(element("history.day").exists, "results keep the day grouping")

        clearSearch()
        search("18000")
        let kopi = transactionRow(containing: "Kopi tubruk")
        XCTAssertTrue(kopi.waitForExistence(timeout: 5), "the amount matches, even months back")
        XCTAssertTrue(digitsOnly(kopi.label).contains("18000 rupiah"), "Rp18.000 is among the results: \(kopi.label)")
        XCTAssertFalse(transactionRow(containing: "Galon").exists, "Rp40.000 doesn't start with 18000")

        clearSearch()
        search("18.000")
        XCTAssertTrue(transactionRow(containing: "Kopi tubruk").waitForExistence(timeout: 5), "digits with the dot match too")
    }

    /// Typing part of a subcategory name suggests it, and choosing the suggestion fills the field (D-057).
    @MainActor
    func testTypingSuggestsASubcategory() throws {
        launchOnRiwayat()
        search("kop")
        let suggestion = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'history.suggestion' AND label CONTAINS %@", "Kopi"))
            .firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5), "Kopi is suggested for \"kop\"")
        suggestion.tap()
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "Kopi", "the suggestion fills the field")
        XCTAssertTrue(transactionRow(containing: "Kopi").waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchWithoutMatchesShowsTheNoResultsState() throws {
        launchOnRiwayat()
        search("sepeda")
        XCTAssertTrue(element("history.noResults").waitForExistence(timeout: 10), "the whole window was searched")
        XCTAssertFalse(element("history.list").exists)
        clearSearch()
        XCTAssertTrue(element("history.list").waitForExistence(timeout: 5), "clearing the search brings the list back")
    }

    /// Tap = Ubah (the edit sheet), swipe = Hapus with the confirmation (D-043, D-044).
    @MainActor
    func testTapEditsAndSwipeDeletes() throws {
        launchOnRiwayat()
        let galon = transactionRow(containing: "Galon")
        XCTAssertTrue(galon.waitForExistence(timeout: 5))
        galon.tap()
        let amount = app.staticTexts["add.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "tap opens the edit sheet")
        XCTAssertTrue(element("add.selected").label.contains("Galon"))
        app.buttons["add.cancel"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))

        galon.swipeLeft()
        let delete = app.buttons.matching(identifier: "transaction.row.delete").firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "swipe shows Hapus")
        delete.tap()
        let confirm = app.buttons.matching(identifier: "transaction.delete.confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Hapus asks first")
        confirm.tap()
        XCTAssertTrue(transactionRow(containing: "Galon").waitForNonExistence(timeout: 5), "the row is gone")
    }

    // MARK: - Helpers

    /// The first element with `identifier`. SwiftUI sometimes puts it on a wrapper and on the control too.
    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func transactionRow(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'transaction.row' AND label CONTAINS %@", text))
            .firstMatch
    }

    @MainActor
    private func monthHeader(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'history.month' AND label CONTAINS %@", text))
            .firstMatch
    }

    /// The month `monthsBack` months before this one as its header names it, e.g. "November 2026".
    private func monthTitle(monthsBack: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(byAdding: .month, value: -monthsBack, to: .now)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    @MainActor
    private func search(_ text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    /// Deletes the search text, leaving the field focused.
    @MainActor
    private func clearSearch() {
        let field = app.searchFields.firstMatch
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
    }

    /// A row's VoiceOver label with digit grouping removed, so amount checks don't depend on separators.
    private func digitsOnly(_ label: String) -> String {
        label.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: ".", with: "")
    }
}
