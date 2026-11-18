import KemanayaCore
import Testing
@testable import Kemanaya

/// The add sheet tints each subcategory tile by its group or kind (D-040).
struct CategoryTintTests {
    @Test func expensesFollowTheirGroup() {
        #expect(CategoryTint(kind: .expense, group: .kebutuhan) == .kebutuhan)
        #expect(CategoryTint(kind: .expense, group: .keinginan) == .keinginan)
    }

    @Test func incomeIsAlwaysPemasukan() {
        #expect(CategoryTint(kind: .income, group: nil) == .pemasukan)
        // An income row can't have a group, but if one did, kind still wins.
        #expect(CategoryTint(kind: .income, group: .keinginan) == .pemasukan)
    }

    /// An expense without a group can't be created (`SubcategoryRules`); the fallback is Kebutuhan.
    @Test func groupLessExpenseFallsBackToKebutuhan() {
        #expect(CategoryTint(kind: .expense, group: nil) == .kebutuhan)
    }

    @Test func everySeededSubcategoryGetsItsSectionTint() {
        for entry in SeedData.income { #expect(CategoryTint(kind: entry.kind, group: entry.group) == .pemasukan) }
        for entry in SeedData.kebutuhan { #expect(CategoryTint(kind: entry.kind, group: entry.group) == .kebutuhan) }
        for entry in SeedData.keinginan { #expect(CategoryTint(kind: entry.kind, group: entry.group) == .keinginan) }
    }
}
