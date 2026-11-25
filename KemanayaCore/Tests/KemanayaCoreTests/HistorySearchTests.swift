import KemanayaCore
import Testing

/// History's search (D-053, D-057): subcategory name and note, case- and diacritic-insensitive; digits
/// match amounts that start with them; predictive suggestions from subcategory names.
struct HistorySearchTests {
    @Test func blankQueryMatchesEverything() {
        for query in ["", "   ", "\n"] {
            let search = HistorySearch(query)
            #expect(search.isEmpty)
            #expect(search.matches(name: "Kopi", note: nil, amount: 18_000))
        }
    }

    @Test func matchesTheNameIgnoringCase() {
        #expect(HistorySearch("kopi").matches(name: "Kopi", note: nil, amount: 18_000))
        #expect(HistorySearch("KOP").matches(name: "Kopi", note: nil, amount: 18_000))
        #expect(HistorySearch("  opi ").matches(name: "Kopi", note: nil, amount: 18_000), "surrounding spaces are trimmed")
        #expect(!HistorySearch("makan").matches(name: "Kopi", note: nil, amount: 18_000))
    }

    /// A seeded subcategory shown as "Food" is still found by its stored name "Makan", and the other way round (D-076).
    @Test func matchesAnyOfTheNames() {
        let names = ["Food", "Makan"]
        #expect(HistorySearch("food").matches(names: names, note: nil, amount: 25_000))
        #expect(HistorySearch("MAK").matches(names: names, note: nil, amount: 25_000))
        #expect(!HistorySearch("kopi").matches(names: names, note: nil, amount: 25_000))
        #expect(HistorySearch("").matches(names: [String](), note: nil, amount: 25_000), "a blank query matches everything")
        #expect(HistorySearch("nasi").matches(names: names, note: "Nasi goreng", amount: 25_000), "the note still counts")
    }

    @Test func matchesTheNoteIgnoringCaseAndDiacritics() {
        let search = HistorySearch("cafe")
        #expect(search.matches(name: "Kopi", note: "Ngopi di Café Tjikini", amount: 45_000))
        #expect(HistorySearch("CAFÉ").matches(name: "Kopi", note: "di cafe", amount: 45_000))
        #expect(HistorySearch("padang").matches(name: "Makan", note: "Nasi Padang", amount: 25_000))
        #expect(!HistorySearch("padang").matches(name: "Makan", note: nil, amount: 25_000))
        #expect(HistorySearch("nasi padang").matches(name: "Makan", note: "Nasi Padang", amount: 25_000), "a phrase matches as a whole")
    }

    /// "18" narrows to every amount whose digits start with 18 (D-057).
    @Test func digitsMatchAmountsThatStartWithThem() {
        let search = HistorySearch("18")
        #expect(search.amountPrefix == "18")
        #expect(search.matches(name: "Kopi", note: nil, amount: 18_000))
        #expect(search.matches(name: "Kopi", note: nil, amount: 180_000))
        #expect(search.matches(name: "Kopi", note: nil, amount: 1_800))
        #expect(search.matches(name: "Kopi", note: nil, amount: 18))
        #expect(!search.matches(name: "Kopi", note: nil, amount: 28_000), "18 is not inside 28000 as a prefix")
        #expect(!search.matches(name: "Kopi", note: nil, amount: 8_000))
        #expect(!search.matches(name: "Kopi", note: nil, amount: 1_000))
    }

    /// Typing more digits narrows further: "18.000" finds Rp18.000 and Rp18.000.000. Separators are ignored
    /// (D-057), so it is the digits 18000, which Rp180.000's digits (180000) also start with.
    @Test func moreDigitsNarrowTheAmounts() {
        for query in ["18000", "18.000", "Rp18.000", "rp 18.000", "Rp 18.000", "RP 18.000", "Rp18000", "18,000", "18 000"] {
            let search = HistorySearch(query)
            #expect(search.amountPrefix == "18000", "\(query)")
            #expect(search.matches(name: "Kopi", note: nil, amount: 18_000), "\(query) finds Rp18.000")
            #expect(search.matches(name: "Kopi", note: nil, amount: 18_000_000), "\(query) finds Rp18.000.000")
            #expect(search.matches(name: "Kopi", note: nil, amount: 180_000), "\(query): 180000 starts with 18000")
            #expect(!search.matches(name: "Kopi", note: nil, amount: 181_000), "\(query) doesn't find Rp181.000")
            #expect(!search.matches(name: "Kopi", note: nil, amount: 28_000), "\(query) doesn't find Rp28.000")
            #expect(!search.matches(name: "Kopi", note: nil, amount: 1_800), "\(query) doesn't find a shorter amount")
            #expect(!search.matches(name: "Kopi", note: nil, amount: 8_000))
        }
    }

    /// Amounts are > 0 (D-016), so their digits never start with 0: "0" matches no amount, only text.
    @Test func zeroMatchesNoAmount() {
        let search = HistorySearch("0")
        #expect(search.amountPrefix == "0")
        #expect(!search.matches(name: "Kopi", note: nil, amount: 10_000))
        #expect(!search.matches(name: "Kopi", note: nil, amount: 100))
        #expect(search.matches(name: "Sewa", note: "Kamar 10", amount: 1_500_000), "the note still matches as text")
        #expect(!HistorySearch("018").matches(name: "Kopi", note: nil, amount: 18_000))
    }

    /// Digits are compared as text, so a query longer than any Int64 can't overflow or crash.
    @Test func longDigitStringsAreSafe() {
        let huge = HistorySearch("99999999999999999999")
        #expect(huge.amountPrefix == "99999999999999999999")
        #expect(!huge.matches(name: "Kopi", note: nil, amount: .max))
        #expect(!huge.matches(name: "Kopi", note: nil, amount: 999_999_999))

        let max = HistorySearch(String(Int64.max))
        #expect(max.matches(name: "Kopi", note: nil, amount: .max))
        let pastMax = HistorySearch(String(Int64.max) + "0")
        #expect(!pastMax.matches(name: "Kopi", note: nil, amount: .max))

        let veryLong = HistorySearch(String(repeating: "1", count: 10_000))
        #expect(veryLong.amountPrefix?.count == 10_000)
        #expect(!veryLong.matches(name: "Kopi", note: nil, amount: 111_111))
    }

    /// A digit query still matches text, e.g. a number in the note.
    @Test func digitsAlsoMatchTheNote() {
        #expect(HistorySearch("18").matches(name: "Sewa", note: "Kamar 18", amount: 1_500_000))
        #expect(HistorySearch("77").matches(name: "Sewa", note: "Kamar 77", amount: 1_500_000))
        #expect(!HistorySearch("77").matches(name: "Sewa", note: "Kamar 18", amount: 1_500_000))
    }

    @Test func notAnAmount() {
        #expect(HistorySearch("kopi").amountPrefix == nil)
        #expect(HistorySearch("18rb").amountPrefix == nil, "no abbreviations")
        #expect(HistorySearch("Rp").amountPrefix == nil, "no digits")
        #expect(HistorySearch("...").amountPrefix == nil)
        #expect(HistorySearch("-18000").amountPrefix == nil, "amounts are positive")
        #expect(HistorySearch("١٨").amountPrefix == nil, "ASCII digits only")
        #expect(!HistorySearch("-18000").matches(name: "Kopi", note: nil, amount: 18_000))
    }

    // MARK: - Suggestions

    private let names = ["Makan", "Kopi", "Jajan", "Parkir", "Galon", "Nongkrong", "Gaji", "Kopdar", "Ngopi"]

    /// Names starting with the query first, then names that only contain it, each alphabetical.
    @Test func suggestionsRankPrefixMatchesFirst() {
        #expect(HistorySearch("kop").suggestions(from: names) == ["Kopdar", "Kopi"])
        #expect(HistorySearch("op").suggestions(from: names) == ["Kopdar", "Kopi", "Ngopi"])
        #expect(HistorySearch("ng").suggestions(from: names) == ["Ngopi", "Nongkrong"], "prefix Ngopi before Nongkrong")
    }

    @Test func suggestionsAreCappedAndAlphabetical() {
        let all = HistorySearch("a").suggestions(from: names)
        #expect(all == ["Gaji", "Galon", "Jajan", "Kopdar", "Makan"], "none starts with a: alphabetical, at most 5")
        #expect(HistorySearch("a").suggestions(from: names, limit: 2) == ["Gaji", "Galon"])
        #expect(HistorySearch("a").suggestions(from: names, limit: 0).isEmpty)
        #expect(HistorySearch("ma").suggestions(from: names) == ["Makan"])
    }

    /// Folded like the search: case, diacritics and width.
    @Test func suggestionsFoldCaseDiacriticsAndWidth() {
        let names = ["Caféku", "Kopi", "ＫＯＰＩ２"]
        #expect(HistorySearch("CAFE").suggestions(from: names) == ["Caféku"])
        #expect(HistorySearch("café").suggestions(from: names) == ["Caféku"])
        #expect(HistorySearch("kop").suggestions(from: names) == ["Kopi", "ＫＯＰＩ２"])
    }

    /// Once a name is typed in full (or chosen), it isn't suggested again.
    @Test func suggestionsLeaveOutTheNameAlreadyTyped() {
        #expect(HistorySearch("Kopi").suggestions(from: names).isEmpty)
        #expect(HistorySearch("KOPI").suggestions(from: ["Kopi", "Kopi2"]) == ["Kopi2"])
    }

    @Test func suggestionsHaveNoDuplicates() {
        #expect(HistorySearch("kop").suggestions(from: ["Kopi", "Kopi", "kopi", "KOPI"]) == ["Kopi"])
    }

    @Test func noSuggestionsForABlankQueryOrNoMatch() {
        #expect(HistorySearch("").suggestions(from: names).isEmpty)
        #expect(HistorySearch("   ").suggestions(from: names).isEmpty)
        #expect(HistorySearch("sepeda").suggestions(from: names).isEmpty)
        #expect(HistorySearch("18").suggestions(from: names).isEmpty)
    }
}
