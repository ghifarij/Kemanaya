/// Which expenses Analisis shows (D-051): **Semua**, **Kebutuhan** or **Keinginan**.
/// It drives the Breakdown donut and ranked list and the daily / weekly spending chart.
/// Income is never included: Analisis ranks spending only, and Home shows income.
public enum ExpenseFilter: String, CaseIterable, Hashable, Sendable {
    /// Both groups.
    case all
    /// Kebutuhan only.
    case kebutuhan
    /// Keinginan only.
    case keinginan

    /// The one group this filter keeps, or nil for ``all``.
    public var group: ExpenseGroup? {
        switch self {
        case .all: nil
        case .kebutuhan: .kebutuhan
        case .keinginan: .keinginan
        }
    }

    /// The groups this filter keeps, in display order (Kebutuhan first).
    public var groups: [ExpenseGroup] {
        group.map { [$0] } ?? ExpenseGroup.allCases
    }

    /// Whether spending in `group` passes. A nil group (income, or an invalid expense) never does.
    public func includes(group: ExpenseGroup?) -> Bool {
        guard let group else { return false }
        return self.group.map { $0 == group } ?? true
    }

    /// Whether `transaction` passes: an expense in a kept group.
    public func includes(_ transaction: TransactionSnapshot) -> Bool {
        transaction.kind == .expense && includes(group: transaction.group)
    }
}
