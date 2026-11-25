import Foundation
import KemanayaCore
import Testing
@testable import Kemanaya

/// D-076: seeded subcategory names come from the String Catalog in both languages until renamed.
struct SubcategoryNamesTests {
    private var seed: [SeedData.Entry] { Array(SeedData.sections.joined()) }

    /// The value of `resource` in one of the app's localizations, read from its `.lproj`.
    private func value(of resource: LocalizedStringResource, in language: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"), "no \(language).lproj")
        let bundle = try #require(Bundle(path: path))
        return bundle.localizedString(forKey: resource.key, value: "∅", table: nil)
    }

    /// Indonesian is the source language and has no `.lproj` of its own: it shows each key's default
    /// value, which is the seed name. The key names the entry, so a typo can't point at another seed.
    @Test func everySeedEntryHasACatalogName() throws {
        for entry in seed {
            let resource = try #require(SubcategoryNames.resource(for: entry), "\(entry.name) has no catalog entry")
            #expect(resource.key == "subcategory.seed.\(entry.name.lowercased())")
        }
    }

    /// English names follow D-007 (one word, ≤ 10 characters) and never collide, ignoring case and
    /// diacritics like the duplicate-name rule (D-062).
    @Test func englishNamesAreValidAndDistinct() throws {
        var keys: Set<String> = []
        for entry in seed {
            let resource = try #require(SubcategoryNames.resource(for: entry))
            let english = try value(of: resource, in: "en")
            #expect(english != "∅", "\(entry.name) has no English")
            #expect(SubcategoryRules.isValidName(english), "\(english) breaks D-007")
            #expect(keys.insert(SubcategoryRules.comparisonKey(english)).inserted, "\(english) is used twice")
        }
    }

    @Test func spotChecksOfTheEnglishNames() throws {
        let expected = ["Makan": "Food", "Ojol": "Ride", "Gas": "LPG", "Galon": "Gallon", "Kopi": "Coffee", "Gaji": "Salary", "Kado": "Presents"]
        for (indonesian, english) in expected {
            let entry = try #require(seed.first { $0.name == indonesian })
            #expect(try value(of: #require(SubcategoryNames.resource(for: entry)), in: "en") == english)
        }
    }

    @Test func aRenamedOrUserSubcategoryShowsItsStoredName() throws {
        let makan = try #require(seed.first { $0.name == "Makan" })
        #expect(SubcategoryNames.shown(id: makan.id, storedName: "Makanan") == "Makanan")
        #expect(SubcategoryNames.shown(id: UUID(), storedName: "Makan") == "Makan", "not a seed id")
        #expect(SubcategoryNames.all(id: UUID(), storedName: "Bakso") == ["Bakso"])
    }

    /// Whatever the test host's language, a seed row goes by its catalog name and is also found by its stored name.
    @Test func aSeedRowGoesByItsShownAndStoredNames() throws {
        let makan = try #require(seed.first { $0.name == "Makan" })
        let shown = SubcategoryNames.shown(id: makan.id, storedName: "Makan")
        #expect(["Makan", "Food"].contains(shown))
        #expect(Set(SubcategoryNames.all(id: makan.id, storedName: "Makan")) == ["Makan", shown])
        #expect(SubcategoryNames.seed("Makan") == shown)
    }
}
