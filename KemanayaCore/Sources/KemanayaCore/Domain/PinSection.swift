/// Where a pinned subcategory sits on Home (D-068): the Kebutuhan column, the Keinginan column, or the
/// income rows below them. Each has its own pin limit; the pins share one Home order (`pinOrder`), which
/// Home and Atur filter per section.
public enum PinSection: String, CaseIterable, Hashable, Sendable {
    case kebutuhan
    case keinginan
    case pemasukan

    /// Kebutuhan / Keinginan for expenses by group, Pemasukan for income. An expense without a group
    /// can't exist (``SubcategoryRules/isValidPlacement(kind:group:)``); it falls back to Kebutuhan.
    public init(kind: TransactionKind, group: ExpenseGroup?) {
        switch (kind, group) {
        case (.income, _): self = .pemasukan
        case (.expense, .keinginan): self = .keinginan
        case (.expense, .kebutuhan), (.expense, nil): self = .kebutuhan
        }
    }

    /// The section of an expense group.
    public init(_ group: ExpenseGroup) {
        self.init(kind: .expense, group: group)
    }

    /// Most pins this section holds at once (D-068): six cards per expense column, three income rows.
    public var limit: Int {
        switch self {
        case .kebutuhan, .keinginan: 6
        case .pemasukan: 3
        }
    }
}

extension Subcategory {
    /// The Home section this subcategory pins into (D-068).
    public var pinSection: PinSection { PinSection(kind: kind, group: group) }
}
