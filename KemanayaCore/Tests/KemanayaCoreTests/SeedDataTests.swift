import Foundation
import KemanayaCore
import Testing

struct SeedDataTests {
    private var all: [SeedData.Entry] { SeedData.sections.flatMap { $0 } }

    @Test func countsPerSection() {
        #expect(SeedData.income.count == 8)
        #expect(SeedData.kebutuhan.count == 22)
        #expect(SeedData.keinginan.count == 14)
        #expect(all.count == 44)
    }

    @Test func sectionsHaveTheRightKindAndGroup() {
        #expect(SeedData.income.allSatisfy { $0.kind == .income && $0.group == nil })
        #expect(SeedData.kebutuhan.allSatisfy { $0.kind == .expense && $0.group == .kebutuhan })
        #expect(SeedData.keinginan.allSatisfy { $0.kind == .expense && $0.group == .keinginan })
    }

    /// The full D-008 lists, in order.
    @Test func incomeFollowsTheSpec() {
        #expect(SeedData.income.map(\.name) == ["Gaji", "Bonus", "Sampingan", "Usaha", "Investasi", "Hadiah", "Refund", "Lainnya"])
        #expect(SeedData.income.map(\.emoji) == ["💼", "🎉", "💻", "🏪", "📈", "🎁", "↩️", "✨"])
    }

    @Test func kebutuhanFollowsTheSpec() {
        #expect(SeedData.kebutuhan.map(\.name) == [
            "Makan", "Dapur", "Galon", "Gas", "Listrik", "Air", "WiFi", "Pulsa", "Sewa", "Cicilan", "Ojol",
            "Bensin", "Parkir", "Tol", "Transport", "Kesehatan", "Pendidikan", "Asuransi", "Laundry", "Sedekah",
            "Rumah", "Servis",
        ])
        #expect(SeedData.kebutuhan.map(\.emoji) == [
            "🍚", "🥬", "💧", "🔥", "⚡", "🚰", "📶", "📱", "🏠", "💳", "🛵",
            "⛽", "🅿️", "🛣️", "🚆", "💊", "📚", "🛡️", "🧺", "🤲",
            "🧹", "🔧",
        ])
    }

    @Test func keinginanFollowsTheSpec() {
        #expect(SeedData.keinginan.map(\.name) == [
            "Kopi", "Jajan", "Nongkrong", "Delivery", "Olshop", "Fashion", "Skincare", "Hiburan", "Streaming",
            "Game", "Hobi", "Gadget", "Liburan", "Kado",
        ])
        #expect(SeedData.keinginan.map(\.emoji) == [
            "☕", "🍿", "🍽️", "🥡", "📦", "👕", "🧴", "🎬", "📺",
            "🎮", "🎨", "🎧", "🏖️", "🎁",
        ])
    }

    @Test func idsAreUnique() {
        #expect(Set(all.map(\.id)).count == all.count)
    }

    /// Seed ids are persisted and matched on restore (D-019): they must never change.
    @Test func idsNeverChange() {
        #expect(SeedData.income.first?.id == UUID(uuidString: "E84A09B0-1D55-478F-9C05-3F03FBF6AD12"))
        #expect(SeedData.keinginan.first?.id == UUID(uuidString: "35EAADA5-2960-46E0-9195-988270F359DB"))
        #expect(SeedData.kebutuhan.first?.id == UUID(uuidString: "88A3D42E-103C-4B7F-A271-696E175AC398"))
    }

    @Test func everyNameFollowsTheNamingRule() {
        for entry in all {
            #expect(SubcategoryRules.isValidName(entry.name), "\(entry.name)")
            #expect(SubcategoryRules.isValidEmoji(entry.emoji), "\(entry.name) \(entry.emoji)")
        }
    }

    @Test func namesAreUniquePerKind() {
        let expenseNames = (SeedData.kebutuhan + SeedData.keinginan).map(\.name)
        #expect(Set(expenseNames).count == expenseNames.count)
        let incomeNames = SeedData.income.map(\.name)
        #expect(Set(incomeNames).count == incomeNames.count)
    }

    @Test func defaultPinsAreSixExpenseSubcategoriesInSpecOrder() {
        #expect(SeedData.defaultPins == ["Makan", "Kopi", "Jajan", "Parkir", "Galon", "Hiburan"])
        let expenseNames = Set((SeedData.kebutuhan + SeedData.keinginan).map(\.name))
        #expect(SeedData.defaultPins.allSatisfy(expenseNames.contains))
        // Three Kebutuhan and three Keinginan (D-068; still the defaults with no pin limit, D-079).
        let kebutuhan = Set(SeedData.kebutuhan.map(\.name))
        let keinginan = Set(SeedData.keinginan.map(\.name))
        #expect(SeedData.defaultPins.count(where: kebutuhan.contains) == 3)
        #expect(SeedData.defaultPins.count(where: keinginan.contains) == 3)
    }

    // MARK: - D-076: seeded names follow the app language until renamed

    @Test func everySeedIdAndUnchangedNameMatchesItsEntry() {
        for entry in all {
            #expect(SeedData.entry(matching: entry.id, storedName: entry.name) == entry)
        }
    }

    @Test func aRenamedSeedRowNoLongerMatches() throws {
        let makan = try #require(SeedData.kebutuhan.first { $0.name == "Makan" })
        #expect(SeedData.entry(matching: makan.id, storedName: "Makanan") == nil)
        #expect(SeedData.entry(matching: makan.id, storedName: "makan") == nil, "a change of case is a rename too")
        #expect(SeedData.entry(matching: makan.id, storedName: "Kopi") == nil, "another seed's name under this id")
    }

    @Test func aNonSeedIdNeverMatches() {
        #expect(SeedData.entry(matching: UUID(), storedName: "Makan") == nil)
    }

    /// A rollup snapshot (D-017, D-066) carries the subcategory id and the name it had then.
    @Test func aRollupSnapshotMatchesOnlyWithItsSeedName() throws {
        let kopi = try #require(SeedData.keinginan.first { $0.name == "Kopi" })
        let unchanged = RollupSnapshot(month: MonthKey(year: 2025, month: 1), subcategoryID: kopi.id, kind: .expense, group: .keinginan, total: 1, count: 1, name: "Kopi", emoji: "☕")
        let renamed = RollupSnapshot(month: MonthKey(year: 2025, month: 1), subcategoryID: kopi.id, kind: .expense, group: .keinginan, total: 1, count: 1, name: "Ngopi", emoji: "☕")
        #expect(SeedData.entry(matching: unchanged.subcategoryID, storedName: unchanged.name) == kopi)
        #expect(SeedData.entry(matching: renamed.subcategoryID, storedName: renamed.name) == nil)
    }
}

struct SubcategoryRulesTests {
    @Test(arguments: ["Makan", "WiFi", "Pendidikan", "A"])
    func validNames(name: String) {
        #expect(SubcategoryRules.isValidName(name))
    }

    @Test(arguments: ["", "Makan Siang", "Transportasi", " Kopi", "Kopi\n"])
    func invalidNames(name: String) {
        #expect(!SubcategoryRules.isValidName(name))
    }

    @Test(arguments: ["☕", "🅿️", "↩️", "⚡", "🤲", "🛣️", "1️⃣", "🇮🇩", "👍🏽", "👨‍👩‍👧"])
    func validEmojis(emoji: String) {
        #expect(SubcategoryRules.isValidEmoji(emoji))
    }

    /// Includes text-style selections (U+FE0E), a bare keycap and a text-default symbol without U+FE0F.
    @Test(arguments: ["", "a", "1", "#", "☕☕", "☕ ", "1\u{FE0E}", "☕\u{FE0E}", "1\u{20E3}", "\u{21A9}"])
    func invalidEmojis(emoji: String) {
        #expect(!SubcategoryRules.isValidEmoji(emoji))
    }

    @Test func placement() {
        #expect(SubcategoryRules.isValidPlacement(kind: .expense, group: .kebutuhan))
        #expect(SubcategoryRules.isValidPlacement(kind: .income, group: nil))
        #expect(!SubcategoryRules.isValidPlacement(kind: .expense, group: nil))
        #expect(!SubcategoryRules.isValidPlacement(kind: .income, group: .keinginan))
    }
}
