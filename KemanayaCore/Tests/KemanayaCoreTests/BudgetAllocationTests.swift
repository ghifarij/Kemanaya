import KemanayaCore
import Testing

struct BudgetAllocationTests {
    @Test func nothingSetHasNoLine() {
        let allocation = BudgetAllocation(groupBudget: nil, subcategoryBudgets: [nil, nil])
        #expect(allocation.groupBudget == nil)
        #expect(allocation.allocated == 0)
        #expect(allocation.free == nil)
        #expect(allocation.overBy == nil)
        #expect(!allocation.isOverAllocated)
        #expect(allocation.summary == .none)
    }

    @Test func groupBudgetWithoutSlicesHasNoLine() {
        let allocation = BudgetAllocation(groupBudget: 5_000_000, subcategoryBudgets: [nil])
        #expect(allocation.allocated == 0)
        #expect(allocation.free == 5_000_000)
        #expect(allocation.summary == .none)
    }

    @Test func noSubcategoriesAtAll() {
        let allocation = BudgetAllocation(groupBudget: 5_000_000, subcategoryBudgets: [Int64?]())
        #expect(allocation.summary == .none)
    }

    @Test func slicesWithoutGroupBudget() {
        let allocation = BudgetAllocation(groupBudget: nil, subcategoryBudgets: [500_000, nil])
        #expect(allocation.allocated == 500_000)
        #expect(allocation.free == nil)
        #expect(allocation.overBy == nil)
        #expect(allocation.summary == .slicesOnly(allocated: 500_000))
    }

    @Test func partialSlicesLeaveTheRestFree() {
        let allocation = BudgetAllocation(groupBudget: 5_000_000, subcategoryBudgets: [500_000, nil])
        #expect(allocation.free == 4_500_000)
        #expect(allocation.summary == .within(allocated: 500_000, free: 4_500_000))
    }

    @Test func exactSlicesAreNotOver() {
        let allocation = BudgetAllocation(groupBudget: 1_000_000, subcategoryBudgets: [400_000, 600_000])
        #expect(allocation.free == 0)
        #expect(!allocation.isOverAllocated)
        #expect(allocation.summary == .within(allocated: 1_000_000, free: 0))
    }

    @Test func slicesOverTheGroupBudget() {
        let allocation = BudgetAllocation(groupBudget: 5_000_000, subcategoryBudgets: [3_000_000, 2_500_000])
        #expect(allocation.allocated == 5_500_000)
        #expect(allocation.free == nil)
        #expect(allocation.overBy == 500_000)
        #expect(allocation.isOverAllocated)
        #expect(allocation.summary == .over(allocated: 5_500_000, overBy: 500_000))
    }

    @Test func zeroAndNegativeMeanNone() {
        let allocation = BudgetAllocation(groupBudget: 0, subcategoryBudgets: [0, -100, nil, 200_000])
        #expect(allocation.groupBudget == nil)
        #expect(allocation.allocated == 200_000)
        #expect(allocation.summary == .slicesOnly(allocated: 200_000))

        let negativeGroup = BudgetAllocation(groupBudget: -1, subcategoryBudgets: [Int64?]())
        #expect(negativeGroup.groupBudget == nil)
        #expect(negativeGroup.summary == .none)
    }

    @Test func keypadMaximumsAddUpWithoutTrapping() {
        let maximum = AmountEntry.maximum
        let allocation = BudgetAllocation(groupBudget: maximum, subcategoryBudgets: Array(repeating: maximum, count: 3))
        #expect(allocation.allocated == maximum * 3)
        #expect(allocation.overBy == maximum * 2)
        #expect(allocation.summary == .over(allocated: maximum * 3, overBy: maximum * 2))

        let exact = BudgetAllocation(groupBudget: maximum, subcategoryBudgets: [maximum])
        #expect(exact.summary == .within(allocated: maximum, free: 0))
    }

    @Test func extremeValuesClampInsteadOfOverflowing() {
        let allocation = BudgetAllocation(groupBudget: 1, subcategoryBudgets: [Int64.max, Int64.max])
        #expect(allocation.allocated == Int64.max)
        #expect(allocation.overBy == Int64.max - 1)

        let hugeGroup = BudgetAllocation(groupBudget: Int64.max, subcategoryBudgets: [1])
        #expect(hugeGroup.free == Int64.max - 1)
    }
}
