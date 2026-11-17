/// Whether money went out or came in (D-002).
///
/// The raw values are persisted and will be written to the JSON backup (D-019): never rename them.
public enum TransactionKind: String, Codable, CaseIterable, Sendable {
    /// Pengeluaran.
    case expense
    /// Pemasukan.
    case income
}

/// The two fixed parent groups of every expense subcategory (D-003). Income has no group (D-005).
///
/// The raw values are persisted and will be written to the JSON backup (D-019): never rename them.
public enum ExpenseGroup: String, Codable, CaseIterable, Sendable {
    /// Needs.
    case kebutuhan
    /// Wants.
    case keinginan
}
