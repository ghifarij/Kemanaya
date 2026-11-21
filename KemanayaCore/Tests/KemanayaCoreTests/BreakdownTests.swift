import Foundation
@testable import KemanayaCore
import Testing

/// Rincian (D-014, D-051): expense subcategories ranked, with shares, filtered by group.
struct BreakdownTests {
    private let makan = UUID()
    private let kopi = UUID()
    private let jajan = UUID()
    private let parkir = UUID()
    private let gaji = UUID()
    private let date = Fixtures.date(2026, 11, 18)

    private func expense(_ amount: Int64, _ id: UUID, _ group: ExpenseGroup) -> TransactionSnapshot {
        TransactionSnapshot(amount: amount, kind: .expense, group: group, subcategoryID: id, date: date)
    }

    private var month: [TransactionSnapshot] {
        [
            expense(500_000, makan, .kebutuhan), expense(250_000, makan, .kebutuhan),
            expense(200_000, kopi, .keinginan), expense(50_000, jajan, .keinginan),
            TransactionSnapshot(amount: 8_500_000, kind: .income, group: nil, subcategoryID: gaji, date: date),
        ]
    }

    @Test func ranksExpensesLargestFirstWithoutIncome() {
        let breakdown = Breakdown(month)
        #expect(breakdown.slices.map(\.subcategoryID) == [makan, kopi, jajan])
        #expect(breakdown.total == 1_000_000)
        #expect(breakdown.slices.map(\.total) == [750_000, 200_000, 50_000])
        #expect(breakdown.slices.map(\.count) == [2, 1, 1])
        #expect(breakdown.slices.map(\.percent) == [75, 20, 5])
        #expect(breakdown.slices.map(\.share) == [0.75, 0.2, 0.05])
        #expect(!breakdown.slices.contains { $0.subcategoryID == gaji }, "income is never in the breakdown")
        #expect(breakdown.largest?.subcategoryID == makan)
        #expect(breakdown.slices.map(\.group) == [.kebutuhan, .keinginan, .keinginan])
    }

    @Test func filtersByGroupAndRecomputesShares() {
        let keinginan = Breakdown(month, filter: .keinginan)
        #expect(keinginan.slices.map(\.subcategoryID) == [kopi, jajan])
        #expect(keinginan.total == 250_000)
        #expect(keinginan.slices.map(\.percent) == [80, 20])
        #expect(keinginan.filter == .keinginan)

        let kebutuhan = Breakdown(month, filter: .kebutuhan)
        #expect(kebutuhan.slices.map(\.subcategoryID) == [makan])
        #expect(kebutuhan.slices.first?.percent == 100)
        #expect(kebutuhan.slices.first?.share == 1)
    }

    @Test func emptyMonthAndEmptyFilterHaveNoSlicesAndNoDivision() {
        let empty = Breakdown([TransactionSnapshot]())
        #expect(empty.isEmpty)
        #expect(empty.total == 0)
        #expect(empty.largest == nil)

        let onlyKebutuhan = Breakdown([expense(10_000, makan, .kebutuhan)], filter: .keinginan)
        #expect(onlyKebutuhan.isEmpty)
        #expect(onlyKebutuhan.total == 0)

        let onlyIncome = Breakdown([TransactionSnapshot(amount: 5_000, kind: .income, group: nil, subcategoryID: gaji, date: date)])
        #expect(onlyIncome.isEmpty, "income alone leaves the breakdown empty")
    }

    /// Equal totals: more transactions first, then a fixed id order, so the list never reshuffles.
    @Test func tiesKeepAStableOrder() {
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let byCount = Breakdown([
            expense(30_000, first, .kebutuhan),
            expense(15_000, second, .keinginan), expense(15_000, second, .keinginan),
        ])
        #expect(byCount.slices.map(\.subcategoryID) == [second, first], "same total, more transactions first")

        let byID = [expense(20_000, second, .keinginan), expense(20_000, first, .kebutuhan)]
        #expect(Breakdown(byID).slices.map(\.subcategoryID) == [first, second])
        #expect(Breakdown(byID.reversed()).slices.map(\.subcategoryID) == [first, second], "input order doesn't matter")
        #expect(Breakdown(byID).slices.map(\.percent) == [50, 50])
    }

    /// Percents always add up to 100; a tiny slice reads 0 and says it is under one percent.
    @Test func percentsAddUpToOneHundred() {
        let thirds = Breakdown([expense(1, makan, .kebutuhan), expense(1, kopi, .keinginan), expense(1, jajan, .keinginan)])
        #expect(thirds.slices.map(\.percent).reduce(0, +) == 100)
        #expect(thirds.slices.map(\.percent).sorted() == [33, 33, 34])

        let tiny = Breakdown([expense(1_000_000, makan, .kebutuhan), expense(1_000, parkir, .kebutuhan)])
        #expect(tiny.slices.map(\.percent) == [100, 0])
        #expect(tiny.slices.last?.isUnderOnePercent == true)
        #expect(tiny.slices.first?.isUnderOnePercent == false)
    }

    @Test func wholePercentsHandleHugeAmountsAndZero() {
        let huge = Int64.max / 4
        #expect(Breakdown.wholePercents(of: [huge, huge, huge, huge], total: huge * 4 - 3).reduce(0, +) == 100)
        #expect(Breakdown.wholePercents(of: [0, 0], total: 0) == [0, 0])
        #expect(Breakdown.wholePercents(of: [], total: 0).isEmpty)
        // Largest remainder: 2/7, 2/7, 3/7 = 28.57, 28.57, 42.86 → 29, 28, 43; the tie goes to the earlier slice.
        #expect(Breakdown.wholePercents(of: [3, 2, 2], total: 7) == [43, 29, 28])
    }

    /// Analisis shows the top 5 in the donut's order, with Lihat semua only when more are left (D-070).
    @Test func topSlicesKeepTheDonutsOrderAndSayWhenMoreAreLeft() {
        let ids = (0..<7).map { _ in UUID() }
        // 70 000, 60 000, … 10 000: the ranking is the input order.
        let seven = Breakdown(ids.enumerated().map { index, id in
            expense(Int64(7 - index) * 10_000, id, index.isMultiple(of: 2) ? .kebutuhan : .keinginan)
        })
        #expect(Breakdown.topLimit == 5)
        #expect(Array(seven.topSlices()) == Array(seven.slices.prefix(5)))
        #expect(seven.topSlices().map(\.subcategoryID) == Array(ids.prefix(5)))
        #expect(seven.hasMore())
        #expect(seven.topSlices(limit: 7).count == 7)
        #expect(!seven.hasMore(than: 7), "exactly the limit hides nothing")
        #expect(seven.hasMore(than: 6))

        let five = Breakdown(ids.prefix(5).map { expense(10_000, $0, .kebutuhan) })
        #expect(five.topSlices().count == 5)
        #expect(!five.hasMore(), "five rows: no Lihat semua")

        let three = Breakdown(month)
        #expect(three.topSlices().map(\.subcategoryID) == [makan, kopi, jajan], "fewer than the limit: all of them")
        #expect(!three.hasMore())

        #expect(Breakdown([TransactionSnapshot]()).topSlices().isEmpty)
        #expect(!Breakdown([TransactionSnapshot]()).hasMore())
        #expect(seven.topSlices(limit: 0).isEmpty)
        #expect(seven.topSlices(limit: -1).isEmpty, "a negative limit shows nothing")
    }

    /// The filter applies before the cut: Keinginan's top 5 are Keinginan's, not the overall top 5's.
    @Test func topSlicesFollowTheFilter() {
        let ids = (0..<8).map { _ in UUID() }
        let all = Breakdown(ids.enumerated().map { index, id in
            expense(Int64(8 - index) * 10_000, id, index < 4 ? .kebutuhan : .keinginan)
        })
        #expect(all.hasMore())
        let keinginan = Breakdown(summary: MonthSummary(ids.enumerated().map { index, id in
            expense(Int64(8 - index) * 10_000, id, index < 4 ? .kebutuhan : .keinginan)
        }), filter: .keinginan)
        #expect(keinginan.topSlices().map(\.subcategoryID) == Array(ids.suffix(4)))
        #expect(!keinginan.hasMore())
    }

    @Test func buildsFromAnExistingSummary() {
        let summary = MonthSummary(month)
        #expect(Breakdown(summary: summary, filter: .all) == Breakdown(month, filter: .all))
    }
}
